extends RefCounted

# Обёртка над Yandex Games SDK для веб‑экспорта Godot.
# В этой упрощённой версии мы:
# - лишь проверяем, доступен ли rewarded‑API;
# - инициируем показ рекламы через JavaScript;
# - всегда разрешаем продолжение игры после запроса (fire‑and‑forget),
#   чтобы кнопка «Продолжить» работала даже если рекламы нет или SDK вернул ошибку.

var _initialized: bool = false


func _init() -> void:
	if not OS.has_feature("web"):
		print("Yandex Games SDK: Not running on web, adapter disabled")
		return
	call_deferred("_check_initialization")


func _check_initialization() -> void:
	var js_code := "typeof window.ysdk !== 'undefined' || typeof window.yaGamesSDK !== 'undefined' || typeof window.yaGamesAPI !== 'undefined'"
	var ok := bool(JavaScriptBridge.eval(js_code, true))
	_initialized = ok
	if ok:
		print("Yandex Games SDK: API available")
	else:
		print("Yandex Games SDK: API not available yet")


func is_initialized() -> bool:
	if not OS.has_feature("web"):
		return false
	if _initialized:
		return true
	
	var js_code := "typeof window.ysdk !== 'undefined' || typeof window.yaGamesSDK !== 'undefined' || typeof window.yaGamesAPI !== 'undefined'"
	var ok := bool(JavaScriptBridge.eval(js_code, true))
	_initialized = ok
	return ok


# Game Ready API: сообщить платформе, что игра загружена и готова к взаимодействию
func loading_ready() -> void:
	if not OS.has_feature("web"): return
	# Только gameReady() — он внутри вызывает LoadingAPI.ready(); не вызывать ready() дважды
	JavaScriptBridge.eval("(function(){ if(window.__godotReadyCalled) return; window.__godotReadyCalled = true; var a=window.yaGamesAPI; if(a&&typeof a.gameReady==='function')a.gameReady(); })();", false)

# Геймплей начат/возобновлён (уровень, закрытие меню, после рекламы)
func gameplay_start() -> void:
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval("(function(){ var a=window.yaGamesAPI; if(a&&typeof a.gameplayStart==='function')a.gameplayStart(); if(window.ysdk&&window.ysdk.features&&window.ysdk.features.GameplayAPI&&typeof window.ysdk.features.GameplayAPI.start==='function')window.ysdk.features.GameplayAPI.start(); })();", false)

# Геймплей приостановлен/завершён (game over, меню, реклама)
func gameplay_stop() -> void:
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval("(function(){ var a=window.yaGamesAPI; if(a&&typeof a.gameplayStop==='function')a.gameplayStop(); if(window.ysdk&&window.ysdk.features&&window.ysdk.features.GameplayAPI&&typeof window.ysdk.features.GameplayAPI.stop==='function')window.ysdk.features.GameplayAPI.stop(); })();", false)

# Черновик: в черновике авторизация не работает — скрываем «Войти» для модерации
func is_draft_mode() -> bool:
	if not OS.has_feature("web"):
		return false
	var v = JavaScriptBridge.eval("window.__yaGamesDraft === true", true)
	return bool(v)

# Язык из SDK/URL (п. 2.14): для автоопределения языка в игре
func get_sdk_locale() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("window.yaGamesLocale || ''", true)
	return str(v) if v else ""


# SDK pause/resume events (game_api_pause/resume)
func init_sdk_pause_listeners() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(function(){
			if (window.__godotSdkPauseInit) return;
			window.__godotSdkPauseInit = true;
			window.__godotSdkPauseState = '';
			if (window.ysdk && typeof window.ysdk.on === 'function') {
				window.ysdk.on('game_api_pause', function(){ window.__godotSdkPauseState = 'pause'; });
				window.ysdk.on('game_api_resume', function(){ window.__godotSdkPauseState = 'resume'; });
			}
		})();
	""", false)


func get_sdk_pause_state() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("(function(){ var s = window.__godotSdkPauseState || ''; window.__godotSdkPauseState = ''; return s; })()", true)
	return str(v) if v else ""


# Удалённая конфигурация (Remote Config): getFlags() один раз на старте, с локальными defaultFlags
# client_features: массив словарей [{"name": "levels", "value": "5"}, ...]
func get_flags_async(default_flags: Dictionary = {}, client_features: Array = []) -> Dictionary:
	if not OS.has_feature("web"):
		return default_flags
	var df_json := JSON.stringify(default_flags)
	var cf_json := JSON.stringify(client_features)
	var df_esc := df_json.replace("\\", "\\\\").replace("\"", "\\\"")
	var cf_esc := cf_json.replace("\\", "\\\\").replace("\"", "\\\"")
	JavaScriptBridge.eval("window.__godotFlagsDone = false; window.__godotFlags = null;", false)
	var js := """
		(function(){
			var df = JSON.parse("%s");
			var cf = JSON.parse("%s");
			var params = { defaultFlags: df };
			if (cf && cf.length) params.clientFeatures = cf;
			var p = (window.ysdk && typeof window.ysdk.getFlags === 'function')
				? window.ysdk.getFlags(params)
				: Promise.resolve(df);
			p.then(function(flags){
				var o = {};
				for (var k in flags) if (Object.prototype.hasOwnProperty.call(flags, k)) o[k] = String(flags[k]);
				window.__godotFlags = o;
				window.__godotFlagsJson = JSON.stringify(o);
				window.__godotFlagsDone = true;
			}).catch(function(){
				window.__godotFlags = df;
				window.__godotFlagsJson = JSON.stringify(df);
				window.__godotFlagsDone = true;
			});
		})();
	""" % [df_esc, cf_esc]
	JavaScriptBridge.eval(js, false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return default_flags
	var t := 0.0
	while t < 10.0:
		var done: bool = bool(JavaScriptBridge.eval("window.__godotFlagsDone === true", true))
		if done:
			var json_str = JavaScriptBridge.eval("window.__godotFlagsJson || '{}'", true)
			if json_str:
				var parsed = JSON.parse_string(str(json_str))
				if parsed is Dictionary:
					return parsed
			return default_flags
		await tree.create_timer(0.15).timeout
		t += 0.15
	return default_flags


# Игрок: авторизация и имя (https://yandex.ru/dev/games/doc/ru/sdk/sdk-player#auth)
# Возвращает { authorized: bool, name: String }
func get_player_async() -> Dictionary:
	if not OS.has_feature("web"):
		return {"authorized": false, "name": ""}
	JavaScriptBridge.eval("window.__godotPlayerDone = false; window.__godotPlayer = null;", false)
	JavaScriptBridge.eval("""
		(function(){
			if (!window.ysdk || typeof window.ysdk.getPlayer !== 'function') {
				window.__godotPlayer = { authorized: false, name: '' };
				window.__godotPlayerDone = true;
				return;
			}
			window.ysdk.getPlayer().then(function(p){
				window.__godotPlayer = {
					authorized: p.isAuthorized ? p.isAuthorized() : false,
					name: (p.getName ? p.getName() : '') || ''
				};
				window.__godotPlayerDone = true;
			}).catch(function(){
				window.__godotPlayer = { authorized: false, name: '' };
				window.__godotPlayerDone = true;
			});
		})();
	""", false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"authorized": false, "name": ""}
	var t := 0.0
	while t < 5.0:
		var done: bool = bool(JavaScriptBridge.eval("window.__godotPlayerDone === true", true))
		if done:
			var name_val = JavaScriptBridge.eval("window.__godotPlayer && window.__godotPlayer.name !== undefined ? window.__godotPlayer.name : ''", true)
			var auth_val = JavaScriptBridge.eval("window.__godotPlayer && window.__godotPlayer.authorized === true", true)
			return {"authorized": bool(auth_val), "name": str(name_val) if name_val else ""}
		await tree.create_timer(0.15).timeout
		t += 0.15
	return {"authorized": false, "name": ""}


# Локальный флаг: уже авторизовывался в игре
func has_auth_history() -> bool:
	if not OS.has_feature("web"):
		return false
	var v = JavaScriptBridge.eval("try{localStorage.getItem('yg_auth_seen')==='1'}catch(e){false}", true)
	return bool(v)


func set_auth_history() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{localStorage.setItem('yg_auth_seen','1')}catch(e){}", false)


func clear_auth_history() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{localStorage.removeItem('yg_auth_seen')}catch(e){}", false)


# Локальный рекорд (guest): хранится в localStorage
func get_local_best_score(key: String = "yg_best_score") -> int:
	if not OS.has_feature("web"):
		return -1
	var k = key.replace("\\", "\\\\").replace("'", "\\'")
	var v = JavaScriptBridge.eval("try{var v=localStorage.getItem('%s'); v===null?-1:parseInt(v,10)}catch(e){-1}" % [k], true)
	return int(v) if v != null else -1


func set_local_best_score(score: int, key: String = "yg_best_score") -> void:
	if not OS.has_feature("web"):
		return
	var k = key.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("try{localStorage.setItem('%s','%d')}catch(e){}" % [k, maxi(0, score)], false)


# Открыть диалог авторизации; после успеха нужно снова вызвать get_player_async()
# Один синхронный eval без предварительных вызовов — сохраняем контекст жеста для opener
func open_auth_dialog_async() -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval("""
		(function(){
			window.__godotAuthDone = false;
			window.__godotAuthOk = false;
			window.__godotAuthError = '';
			window.__godotAuthPending = true;
			try {
				if (window.yaGamesAPI && typeof window.yaGamesAPI.openAuthDialog === 'function') {
					window.yaGamesAPI.openAuthDialog();
					return;
				}
				if (window.ysdk && window.ysdk.auth && typeof window.ysdk.auth.openAuthDialog === 'function') {
					window.ysdk.auth.openAuthDialog()
						.then(function(){ window.__godotAuthPending = false; window.__godotAuthOk = true; window.__godotAuthDone = true; })
						.catch(function(err){ window.__godotAuthPending = false; window.__godotAuthError = (err && err.message) ? err.message : 'auth_failed'; window.__godotAuthDone = true; });
					return;
				}
			} catch (e) {
				window.__godotAuthPending = false;
				window.__godotAuthError = (e && e.message) ? e.message : 'auth_failed';
			}
			window.__godotAuthPending = false;
			window.__godotAuthDone = true;
		})();
	""", false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var t := 0.0
	while t < 30.0:
		var done: bool = bool(JavaScriptBridge.eval("window.__godotAuthDone === true", true))
		if done:
			return bool(JavaScriptBridge.eval("window.__godotAuthOk === true", true))
		await tree.create_timer(0.2).timeout
		t += 0.2
	return false


# Лидерборд: отправить счёт (https://yandex.ru/dev/games/doc/ru/sdk/sdk-leaderboard)
func leaderboard_set_score(leaderboard_name: String, score: int) -> void:
	if not OS.has_feature("web") or leaderboard_name.is_empty():
		return
	var name_esc := leaderboard_name.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("""
		(function(){
			if (window.ysdk && window.ysdk.leaderboards && typeof window.ysdk.leaderboards.setScore === 'function')
				window.ysdk.leaderboards.setScore('%s', %d);
		})();
	""" % [name_esc, clampi(score, 0, 0x7FFFFFFF)], false)


# Лидерборд: получить записи (quantity_top 1..20)
func leaderboard_get_entries_async(leaderboard_name: String, quantity_top: int = 10) -> Array:
	if not OS.has_feature("web") or leaderboard_name.is_empty():
		return []
	JavaScriptBridge.eval("window.__godotLbDone = false; window.__godotLbEntries = '[]';", false)
	var name_esc := leaderboard_name.replace("\\", "\\\\").replace("'", "\\'")
	var qty := clampi(quantity_top, 1, 20)
	JavaScriptBridge.eval("""
		(function(){
			if (!window.ysdk || !window.ysdk.leaderboards || typeof window.ysdk.leaderboards.getEntries !== 'function') {
				window.__godotLbDone = true;
				return;
			}
			window.ysdk.leaderboards.getEntries('%s', { quantityTop: %d }).then(function(r){
				var list = (r && r.entries) ? r.entries : [];
				window.__godotLbEntries = JSON.stringify(list.map(function(e){ return { rank: e.rank, score: e.score, name: (e.player && e.player.publicName) ? e.player.publicName : '' }; }));
				window.__godotLbDone = true;
			}).catch(function(){ window.__godotLbDone = true; });
		})();
	""" % [name_esc, qty], false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	var t := 0.0
	while t < 10.0:
		var done: bool = bool(JavaScriptBridge.eval("window.__godotLbDone === true", true))
		if done:
			var json_str = JavaScriptBridge.eval("window.__godotLbEntries || '[]'", true)
			if json_str:
				var parsed = JSON.parse_string(str(json_str))
				if parsed is Array:
					return parsed
			return []
		await tree.create_timer(0.15).timeout
		t += 0.15
	return []


# Лидерборд: получить результат текущего игрока (или -1 если записи нет)
func leaderboard_get_player_score_async(leaderboard_name: String) -> int:
	if not OS.has_feature("web") or leaderboard_name.is_empty():
		return -1
	JavaScriptBridge.eval("window.__godotLbPlayerDone = false; window.__godotLbPlayerScore = -1;", false)
	var name_esc := leaderboard_name.replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("""
		(function(){
			if (!window.ysdk || !window.ysdk.leaderboards || typeof window.ysdk.leaderboards.getPlayerEntry !== 'function') {
				window.__godotLbPlayerDone = true;
				return;
			}
			window.ysdk.leaderboards.getPlayerEntry('%s').then(function(r){
				window.__godotLbPlayerScore = (r && typeof r.score === 'number') ? r.score : -1;
				window.__godotLbPlayerDone = true;
			}).catch(function(){ window.__godotLbPlayerDone = true; });
		})();
	""" % [name_esc], false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return -1
	var t := 0.0
	while t < 10.0:
		var done: bool = bool(JavaScriptBridge.eval("window.__godotLbPlayerDone === true", true))
		if done:
			var v = JavaScriptBridge.eval("window.__godotLbPlayerScore", true)
			return int(v) if v != null else -1
		await tree.create_timer(0.15).timeout
		t += 0.15
	return -1


func show_rewarded_ad(on_success: Callable, on_error: Callable) -> void:
	# Вызов rewarded‑видео для Яндекс Игр.
	# ВАЖНО: on_success вызывается ТОЛЬКО после подтверждённой награды
	# (после onRewarded в SDK) или сразу, если рекламы нет/ошибка.
	if not OS.has_feature("web"):
		print("Yandex Games SDK: Not on web platform, skipping ad")
		on_success.call()
		return

	var api_ok := bool(
		JavaScriptBridge.eval(
			"Boolean((window.ysdk && window.ysdk.adv && typeof window.ysdk.adv.showRewardedVideo === 'function') || \
(window.yaGamesSDK && window.yaGamesSDK.adv && typeof window.yaGamesSDK.adv.showRewardedVideo === 'function') || \
(window.yaGamesAPI && typeof window.yaGamesAPI.showRewardedVideo === 'function'))",
			true
		)
	)

	if not api_ok:
		print("Yandex Games SDK: rewarded API not available, continue without ad")
		on_success.call()
		return

	# Сбрасываем и инициализируем глобальные флаги статуса в JS.
	var init_flags := """
		window.godotRewardedDone = false;
		window.godotRewardedGotReward = false;
		window.godotRewardedError = "";
	"""
	JavaScriptBridge.eval(init_flags, false)

	# Запускаем показ рекламы. Колбэки только меняют флаги, опрашиваем их из GDScript.
	var js_code := """
		(function () {
			try {
				var onRewardedCallback = function () {
					// Для yaGamesAPI (старый JS‑SDK) showRewardedVideo(onRewarded, onError)
					// колбэк вызывается уже после полного просмотра и закрытия ролика,
					// поэтому можно сразу считать, что реклама завершена.
					window.godotRewardedGotReward = true;
					window.godotRewardedDone = true;
				};
				var onErrorCallback = function (e) {
					window.godotRewardedError = (e && e.code) || String(e || 'error');
				};
				
				var opts = {
					callbacks: {
						onOpen: function () {},
						onRewarded: function () {
							window.godotRewardedGotReward = true;
						},
						onClose: function () {
							if (window.godotRewardedGotReward) {
								window.godotRewardedDone = true;
							} else {
								window.godotRewardedError = 'closed_without_reward';
							}
						},
						onError: onErrorCallback
					}
				};
				
				var sdk = null;
				var sdkName = '';
				if (window.ysdk && window.ysdk.adv && typeof window.ysdk.adv.showRewardedVideo === 'function') {
					sdk = window.ysdk.adv;
					sdkName = 'ysdk.adv';
				} else if (window.yaGamesSDK && window.yaGamesSDK.adv && typeof window.yaGamesSDK.adv.showRewardedVideo === 'function') {
					sdk = window.yaGamesSDK.adv;
					sdkName = 'yaGamesSDK.adv';
				} else if (window.yaGamesAPI && typeof window.yaGamesAPI.showRewardedVideo === 'function') {
					sdk = window.yaGamesAPI;
					sdkName = 'yaGamesAPI';
				}
				
				if (sdk) {
					if (sdkName === 'yaGamesAPI') {
						// Старый JS‑SDK: showRewardedVideo(onRewarded, onError)
						sdk.showRewardedVideo(onRewardedCallback, onErrorCallback);
					} else {
						// Новый SDK: showRewardedVideo({ callbacks })
						var result = sdk.showRewardedVideo(opts);
						if (result instanceof Promise) {
							result.catch(function(err) {
								window.godotRewardedError = String(err || 'promise_rejected');
							});
						}
					}
				} else {
					window.godotRewardedError = 'api_not_available';
				}
			} catch (e) {
				window.godotRewardedError = String(e || 'exception');
			}
		})();
	"""

	JavaScriptBridge.eval(js_code, false)
	print("Yandex Games SDK: Requested rewarded ad (with JS flags)")
	
	# Запускаем асинхронное ожидание результата рекламы (до награды или ошибки).
	_wait_reward_result(on_success, on_error)


func _wait_reward_result(on_success: Callable, on_error: Callable) -> void:
	# Асинхронный опрос JS-флагов: godotRewardedDone / godotRewardedError.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		# На всякий случай, если по какой-то причине нет SceneTree — сразу даём продолжить.
		on_success.call()
		return

	var max_wait_time := 60.0  # максимум 60 секунд ожидания
	var elapsed_time := 0.0
	
	while elapsed_time < max_wait_time:
		var status_raw = JavaScriptBridge.eval(
			"window.godotRewardedDone ? 'ok' : (window.godotRewardedError || '')",
			true
		)
		var status: String = str(status_raw) if status_raw != null else ""

		if status == "ok":
			on_success.call()
			return
		elif status != "":
			on_error.call(status)
			return

		await tree.create_timer(0.3).timeout
		elapsed_time += 0.3
	
	# Если прошло слишком много времени без ответа, считаем это ошибкой
	on_error.call("timeout")
