extends Node

# Offline compatibility for dormant desktop services; no networking or SDK is loaded.
signal avatar_loaded
signal join_requested
signal leaderboard_find_result
signal leaderboard_score_uploaded
signal leaderboard_scores_downloaded
signal lobby_chat_update
signal lobby_created
signal lobby_joined
signal lobby_match_list
signal p2p_session_connect_fail
signal p2p_session_request
signal persona_state_change

const CHAT_MEMBER_STATE_CHANGE_BANNED = 1
const CHAT_MEMBER_STATE_CHANGE_ENTERED = 2
const CHAT_MEMBER_STATE_CHANGE_KICKED = 3
const CHAT_MEMBER_STATE_CHANGE_LEFT = 4
const CHAT_ROOM_ENTER_RESPONSE_BANNED = 5
const CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED = 6
const CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN = 7
const CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST = 8
const CHAT_ROOM_ENTER_RESPONSE_ERROR = 9
const CHAT_ROOM_ENTER_RESPONSE_FULL = 10
const CHAT_ROOM_ENTER_RESPONSE_LIMITED = 11
const CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU = 12
const CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED = 13
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS = 14
const CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER = 15
const LEADERBOARD_DATA_REQUEST_FRIENDS = 16
const LEADERBOARD_DATA_REQUEST_GLOBAL = 17
const LEADERBOARD_DATA_REQUEST_GLOBAL_AROUND_USER = 18
const LOBBY_DISTANCE_FILTER_CLOSE = 19
const LOBBY_DISTANCE_FILTER_FAR = 20
const LOBBY_DISTANCE_FILTER_WORLDWIDE = 21
const LOBBY_TYPE_FRIENDS_ONLY = 22
const LOBBY_TYPE_PUBLIC = 23
const P2P_SEND_RELIABLE = 24

func acceptP2PSessionWithUser(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func activateGameOverlayInviteDialog(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func addRequestLobbyListDistanceFilter(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func addRequestLobbyListResultCountFilter(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func allowP2PPacketRelay(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func clearAchievement(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func closeP2PSessionWithUser(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func createLobby(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func downloadLeaderboardEntries(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func findLeaderboard(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getAvailableP2PPacketSize(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getFriendPersonaName(_a = null, _b = null, _c = null, _d = null, _e = null):
	return ""

func getLeaderboardEntryCount(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getLobbyData(_a = null, _b = null, _c = null, _d = null, _e = null):
	return ""

func getLobbyMemberByIndex(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getLobbyOwner(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getNumLobbyMembers(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getPersonaName(_a = null, _b = null, _c = null, _d = null, _e = null):
	return ""

func getPlayerAvatar(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func getSteamID(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func isSteamRunningOnSteamDeck(_a = null, _b = null, _c = null, _d = null, _e = null):
	return false

func joinLobby(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func leaveLobby(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func loggedOn(_a = null, _b = null, _c = null, _d = null, _e = null):
	return false

func readP2PPacket(_a = null, _b = null, _c = null, _d = null, _e = null):
	return {}

func requestLobbyList(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func run_callbacks(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func sendP2PPacket(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func setAchievement(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func setLeaderboardDetailsMax(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func setLobbyData(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func setLobbyJoinable(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func setLobbyMemberLimit(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func setLobbyType(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func steamInit(_a = null, _b = null, _c = null, _d = null, _e = null):
	return {"status": 1, "verbal": "Offline mobile port"}

func storeStats(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

func uploadLeaderboardScore(_a = null, _b = null, _c = null, _d = null, _e = null):
	return 0

