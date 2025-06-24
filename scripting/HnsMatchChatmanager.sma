#include <amxmodx>
#include <reapi>
#include <hns_matchsystem_dbmysql>

#define PLUGIN "Match: ChatManager"
#define VERSION "1.1"
#define AUTHOR "Mistrick, OpenHNS"

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

#define ADMIN_FLAG ADMIN_CHAT

//Colors: DEFAULT, TEAM, GREEN
#define PRETEXT_COLOR            DEFAULT
#define PLAYER_CHAT_COLOR        DEFAULT
#define ADMIN_CHAT_COLOR         GREEN
#define PLAYER_NAME_COLOR        TEAM
#define ADMIN_NAME_COLOR         TEAM

//Flags: DEFAULT_CHAT, ALIVE_SEE_DEAD, DEAD_SEE_ALIVE, TEAM_SEE_TEAM
#define PLAYER_CHAT_FLAGS (ALIVE_SEE_DEAD|DEAD_SEE_ALIVE)
#define ADMIN_CHAT_FLAGS (ALIVE_SEE_DEAD|DEAD_SEE_ALIVE)

new const TEAM_NAMES[CsTeams][] = {
    "(Spectator)",
    "(Terrorist)",
    "(Counter-Terrorist)",
    "(Spectator)"
};

#define CHECK_NATIVE_ARGS_NUM(%1,%2,%3) \
    if (%1 < %2) { \
        log_error(AMX_ERR_NATIVE, "Invalid num of arguments %d. Expected %d", %1, %2); \
        return %3; \
    }

#define CHECK_NATIVE_PLAYER(%1,%2) \
    if (!is_user_connected(%1)) { \
        log_error(AMX_ERR_NATIVE, "Invalid player %d", %1); \
        return %2; \
    }

const DEFAULT_CHAT = 0;
const ALIVE_SEE_DEAD = (1 << 0);
const DEAD_SEE_ALIVE = (1 << 1);
const TEAM_SEE_TEAM = (1 << 2);

enum {
    DEFAULT = 1,
    TEAM = 3,
    GREEN = 4
};

enum _:FLAG_PREFIX_INFO {
    m_Flag,
    m_Prefix[32]
};

new const g_TextChannels[][] = {
    "#Cstrike_Chat_All",
    "#Cstrike_Chat_AllDead",
    "#Cstrike_Chat_T",
    "#Cstrike_Chat_T_Dead",
    "#Cstrike_Chat_CT",
    "#Cstrike_Chat_CT_Dead",
    "#Cstrike_Chat_Spec",
    "#Cstrike_Chat_AllSpec"
};

new g_SayText;
new g_sMessage[173];

new const FILE_PREFIXES[] = "openhns-prefixes.ini";

new g_bCustomPrefix[33], g_sPlayerPrefix[33][32];
new Trie:g_tSteamPrefixes, g_iTrieSteamSize;
new Trie:g_tNamePrefixes, g_iTrieNameSize;
new Array:g_aFlagPrefixes, g_iArrayFlagSize;

new g_szLogFile[128];

enum Forwards {
    SEND_MESSAGE
};

enum _:MessageReturn {
    MESSAGE_IGNORED,
    MESSAGE_CHANGED,
    MESSAGE_BLOCKED
};

new g_iForwards[Forwards];
new g_sNewMessage[173];


public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    register_clcmd("say", "clcmd__say_handler");
    register_clcmd("say_team", "clcmd__say_handler");
    
    register_message((g_SayText = get_user_msgid("SayText")), "message__say_text");

    // cm_player_send_message(id, message[], team_chat);
    g_iForwards[SEND_MESSAGE] = CreateMultiForward("cm_player_send_message", ET_STOP, FP_CELL, FP_STRING, FP_CELL);
}
public plugin_cfg() {
    new dir[] = "addons/amxmodx/logs/chatmanager";
    if(!dir_exists(dir)) {
        mkdir(dir);
    }
    new date[16]; get_time("%Y-%m-%d", date, charsmax(date));
    formatex(g_szLogFile, charsmax(g_szLogFile), "%s/chatlog_%s.html", dir, date);
    if(!file_exists(g_szLogFile)) {
        write_file(g_szLogFile, "<meta charset=utf-8><title>ChatManager Log</title>");
    }
    
    LoadPlayersPrefixes();
}

LoadPlayersPrefixes() {
    new dir[128]; get_localinfo("amxx_configsdir", dir, charsmax(dir));
    new file_name[128]; formatex(file_name, charsmax(file_name), "%s/%s", dir, FILE_PREFIXES);
    
    if(!file_exists(file_name)) {
        log_amx("Prefixes file doesn't exist!");
        return;
    }
    
    g_tSteamPrefixes = TrieCreate();
    g_tNamePrefixes = TrieCreate();
    g_aFlagPrefixes = ArrayCreate(FLAG_PREFIX_INFO);
    
    new file = fopen(file_name, "rt");
    
    if(file) {
        new text[128], type[6], auth[32], prefix[32 + 6], prefix_info[FLAG_PREFIX_INFO];
        while(!feof(file)) {
            fgets(file, text, charsmax(text));
            parse(text, type, charsmax(type), auth, charsmax(auth), prefix, charsmax(prefix));
            
            if(!type[0] || type[0] == ';' || !auth[0] || !prefix[0]) continue;
            
            replace_color_tag(prefix);
            
            switch(type[0]) {
                case 's': {
                    TrieSetString(g_tSteamPrefixes, auth, prefix);
                    g_iTrieSteamSize++;
                }
                case 'n': {
                    TrieSetString(g_tNamePrefixes, auth, prefix);
                    g_iTrieNameSize++;
                }
                case 'f': {
                    prefix_info[m_Flag] = read_flags(auth);
                    copy(prefix_info[m_Prefix], charsmax(prefix_info[m_Prefix]), prefix);
                    ArrayPushArray(g_aFlagPrefixes, prefix_info);
                    g_iArrayFlagSize++;
                }
            }
        }
        fclose(file);
    }
}

public plugin_natives() {
    register_native("cm_set_player_message", "native_set_player_message");

    register_native("cm_set_prefix", "native_set_prefix");
    register_native("cm_get_prefix", "native_get_prefix");
    register_native("cm_reset_prefix", "native_reset_prefix");

    set_native_filter("hns_dbmysql_filter");
}

public native_set_player_message(plugin, params) {
    enum { arg_new_message = 1 };
    get_string(arg_new_message, g_sNewMessage, charsmax(g_sNewMessage));
}

public native_set_prefix(plugin, params) {
    enum { 
        arg_player = 1,
        arg_prefix
    };

    CHECK_NATIVE_ARGS_NUM(params, arg_prefix, 0)
    new player = get_param(arg_player);
    CHECK_NATIVE_PLAYER(player, 0)

    get_string(arg_prefix, g_sPlayerPrefix[player], charsmax(g_sPlayerPrefix[]));
    g_bCustomPrefix[player] = true;
    return 1;
}

public native_get_prefix(plugin, params) {
    enum {
        arg_player = 1,
        arg_dest,
        arg_length
    };
    
    CHECK_NATIVE_ARGS_NUM(params, arg_length, 0)
    new player = get_param(arg_player);
    CHECK_NATIVE_PLAYER(player, 0)

    if (!g_bCustomPrefix[player]) {
        return 0;
    }

    return set_string(arg_dest, g_sPlayerPrefix[player], get_param(arg_length));
}
public native_reset_prefix(plugin, params) {
    enum { arg_player = 1 };

    CHECK_NATIVE_ARGS_NUM(params, arg_player, 0)
    new player = get_param(arg_player);
    CHECK_NATIVE_PLAYER(player, 0)

    arrayset(g_sPlayerPrefix[player], 0, sizeof g_sPlayerPrefix[]);
    g_bCustomPrefix[player] = false;
    return 1;
}

public client_putinserver(id) {
    g_sPlayerPrefix[id] = "";
    g_bCustomPrefix[id] = false;
    
    new steamid[32];
    get_user_authid(id, steamid, charsmax(steamid));
    if(g_iTrieSteamSize && TrieKeyExists(g_tSteamPrefixes, steamid)) {
        g_bCustomPrefix[id] = true;
        TrieGetString(g_tSteamPrefixes, steamid, g_sPlayerPrefix[id], charsmax(g_sPlayerPrefix[]));
    }
}

public clcmd__say_handler(id) {
    if (!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }
    
    new message[128];
    
    read_argv(0, message, charsmax(message));
    new is_team_msg = (message[3] == '_');
    
    read_args(message, charsmax(message));
    remove_quotes(message);
    replace_wrong_simbols(message);
    trim(message);
    
    if(!message[0]) {
        return PLUGIN_HANDLED;
    }
    
    if(message[0] == '/') {
        return PLUGIN_HANDLED_MAIN;
    }
    
    new flags, name[32];
    flags = get_user_flags(id);
    get_user_name(id, name, charsmax(name));
    
    if(!g_bCustomPrefix[id]) {
        if(g_iTrieNameSize && TrieKeyExists(g_tNamePrefixes, name)) {
            TrieGetString(g_tNamePrefixes, name, g_sPlayerPrefix[id], charsmax(g_sPlayerPrefix[]));
        } else if(g_iArrayFlagSize) {
            new prefix_info[FLAG_PREFIX_INFO], bFoundPrefix = false;
            for(new i; i < g_iArrayFlagSize; i++) {
                ArrayGetArray(g_aFlagPrefixes, i, prefix_info);
                if(check_flags(flags, prefix_info[m_Flag])) {
                    bFoundPrefix = true;
                    copy(g_sPlayerPrefix[id], charsmax(g_sPlayerPrefix[]), prefix_info[m_Prefix]);
                    break;
                }
            }
            
            if(!bFoundPrefix) {
                g_sPlayerPrefix[id] = "";
            }
        }
    }
    
    new ret; ExecuteForward(g_iForwards[SEND_MESSAGE], ret, id, message, is_team_msg);

    if(ret) {
        if(ret == MESSAGE_BLOCKED) {
            return PLUGIN_HANDLED;
        }
        copy(message, charsmax(message), g_sNewMessage);
    }

    if(!message[0]) {
        return PLUGIN_HANDLED;
    }

    new name_color = flags & ADMIN_FLAG ? ADMIN_NAME_COLOR : PLAYER_NAME_COLOR;
    new chat_color = flags & ADMIN_FLAG ? ADMIN_CHAT_COLOR : PLAYER_CHAT_COLOR;
    
    new time_code[16];
    get_time("[%H:%M:%S] ", time_code, charsmax(time_code));
    
    new is_sender_alive = is_user_alive(id);
    new CsTeams:sender_team = rg_get_user_team(id);
    
    new channel = get_user_text_channel(is_sender_alive, is_team_msg, sender_team);
    
    FormatMessage(id, sender_team, channel, name_color, chat_color, time_code, name, message);
    
    new players[32], players_num, player, is_player_alive, CsTeams:player_team, player_flags;
    get_players(players, players_num, "ch");
    
    for(new i; i < players_num; i++) {
        player = players[i];
        
        if(player == id) {
            continue;
        }
        
        is_player_alive = is_user_alive(player);
        player_team = rg_get_user_team(player);
        player_flags = get_user_flags(player) & ADMIN_FLAG ? ADMIN_CHAT_FLAGS : PLAYER_CHAT_FLAGS;
        
        if(player_flags & ALIVE_SEE_DEAD && !is_sender_alive && is_player_alive && (!is_team_msg || is_team_msg && sender_team == player_team) //flag ALIVE_SEE_DEAD
        || player_flags & DEAD_SEE_ALIVE && is_sender_alive && !is_player_alive && (!is_team_msg || is_team_msg && sender_team == player_team) //flag DEAD_SEE_ALIVE
        || player_flags & TEAM_SEE_TEAM && is_team_msg && sender_team != player_team) //flag TEAM_SEE_TEAM
        {
            emessage_begin(MSG_ONE, g_SayText, _, player);
            ewrite_byte(id);
            ewrite_string(g_TextChannels[channel]);
            ewrite_string("");
            ewrite_string("");
            emessage_end();
        }
    }
    
    static const team_color[CsTeams][] = {"gray", "red", "blue", "gray"};
    new log_msg[256];
    formatex(log_msg, charsmax(log_msg), "<br><font color=black>%s %s %s <font color=%s><b>%s</b> </font>:</font><font color=%s> %s </font>", time_code, is_sender_alive ? "" : (_:sender_team == 1 || _:sender_team == 2 ? "*DEAD*" : "*SPEC*"), is_team_msg ? "(TEAM)" : "", team_color[sender_team], name, chat_color == GREEN ? "green" : "#FFB41E", message);
    write_file(g_szLogFile, log_msg);
    
    return PLUGIN_CONTINUE;
}

public FormatMessage(sender, CsTeams:sender_team, channel, name_color, chat_color, time_code[], name[], message[]) {
    new text[173], len = 1;
    text[0] = PRETEXT_COLOR;

    // TODO: Добавить префикс капитана. Изменить чат команде: (Team)
    
    if(channel % 2) {
        len += formatex(text[len], charsmax(text) - len, "%s", channel != 7 ? "[Dead]" : "[Spec]");
    }
    
    if(channel > 1 && channel < 7) {
        len += formatex(text[len], charsmax(text) - len, "%s ", TEAM_NAMES[sender_team]);
    } else if(channel) {
        len += formatex(text[len], charsmax(text) - len, " ");
    }
    
    /* HNS MATCH PTS */
    if (hns_db_init()) {
        len += formatex(text[len], charsmax(text) - len, "^1[^3%s^1] ", get_skill_player(sender));
    }
    /* HNS MATCH PTS */

    len += formatex(text[len], charsmax(text) - len, "%s", g_sPlayerPrefix[sender]);
    
    len += formatex(text[len], charsmax(text) - len, "%c%s^1 :%c %s", name_color, name, chat_color, message);
    
    copy(g_sMessage, charsmax(g_sMessage), text);
}

public message__say_text(msgid, dest, receiver) {
    if(get_msg_args() != 4) {
        return PLUGIN_CONTINUE;
    }
    
    new str2[22], channel;

    get_msg_arg_string(2, str2, charsmax(str2));
    channel = get_msg_channel(str2);
    
    if(!channel) {
        return PLUGIN_CONTINUE;
    }
    
    new str3[2];
    get_msg_arg_string(3, str3, charsmax(str3));
    
    if(str3[0]) {
        return PLUGIN_CONTINUE;
    }
    
    set_msg_arg_string(2, "#Spec_PlayerItem");
    set_msg_arg_string(3, g_sMessage);
    set_msg_arg_string(4, "");
    
    return PLUGIN_CONTINUE;
}

get_msg_channel(str[]) {
    for(new i; i < sizeof(g_TextChannels); i++) {
        if(equal(str, g_TextChannels[i])) {
            return i + 1;
        }
    }
    return 0;
}

stock get_user_text_channel(is_sender_alive, is_team_msg, CsTeams:sender_team) {
    if (is_team_msg) {
        switch(sender_team) {
            case CS_TEAM_T: {
                return is_sender_alive ? 2 : 3;
            }
            case CS_TEAM_CT: {
                return is_sender_alive ? 4 : 5;
            }
            default: {
                return 6;
            }
        }
    }
    return is_sender_alive ? 0 : (sender_team == CS_TEAM_SPECTATOR ? 7 : 1);
}

stock replace_wrong_simbols(string[]) {
    new len = 0;
    for(new i; string[i] != EOS; i++) {
        if(/* string[i] == '%' || string[i] == '#' || */ 0x01 <= string[i] <= 0x04) {
            continue;
        }
        string[len++] = string[i];
    }
    string[len] = EOS;
}

replace_color_tag(string[]) {
    new len = 0;
    for (new i; string[i] != EOS; i++) {
        if (string[i] == '!') {
            switch (string[++i]) {
                case 'd': string[len++] = 0x01;
                case 't': string[len++] = 0x03;
                case 'g': string[len++] = 0x04;
                case EOS: break;
                default: string[len++] = string[i];
            }
        } else {
            string[len++] = string[i];
        }
    }
    string[len] = EOS;
}

stock check_flags(flags, need_flags) {
    return ((flags & need_flags) == need_flags) ? 1 : 0;
}