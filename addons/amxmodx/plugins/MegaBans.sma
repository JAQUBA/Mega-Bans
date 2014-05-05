#include <amxmodx>
#include <amxmisc>
#include <jqb/mysql>

#pragma semicolon 1

#define VERSION "1.0 beta"


enum _:CvarStruct {
	cSqlHostname,
	cSqlUsername,
	cSqlPassword,
	cSqlDatabase,
	cSqlPrefix,
	
	cSite,
	
	cTimeOffset
}
enum _:GlobalStruct {
	gSzPrefix[17],
	gSzSite[65],
	gServerID,
	gSzServerIP[22],
	gTimeOffset
}
enum _:AdminDataStruct {
	admSzAuth[33],
	admSzPassword[33],
	admIAccess,
	admIFlags
}

new Cvar[CvarStruct];
new Global[GlobalStruct];

new Array:aAdmins;

public plugin_init() {
	register_plugin("Mega Bans",VERSION,"JAQUBA");
	
	Cvar[cSqlHostname]=register_cvar("mb_sql_hostname","localhost");
	Cvar[cSqlUsername]=register_cvar("mb_sql_username","username");
	Cvar[cSqlPassword]=register_cvar("mb_sql_password","password");
	Cvar[cSqlDatabase]=register_cvar("mb_sql_database","database");
	Cvar[cSqlPrefix]=register_cvar("mb_sql_prefix","mb");
	
	Cvar[cSite]=register_cvar("mb_site","www.site.com");
	
	Cvar[cTimeOffset]=register_cvar("mb_timeoffset","0");
	
	get_user_ip(0,Global[gSzServerIP],charsmax(Global[gSzServerIP]));
	
	aAdmins=ArrayCreate(AdminDataStruct);
	
	register_dictionary("admin.txt");
	
	register_concmd("amx_reloadadmins", "cmdReload", ADMIN_CFG);
	remove_user_flags(0, read_flags("z"));
}
public plugin_cfg() {
	new szConfigsDir[65];
	get_configsdir(szConfigsDir,charsmax(szConfigsDir));
	server_cmd("exec %s/megabans.cfg",szConfigsDir);
	server_exec();
	
	new szHostname[65],szUsername[65],szPassword[65],szDatabase[65];
	get_pcvar_string(Cvar[cSqlHostname],szHostname,charsmax(szHostname));
	get_pcvar_string(Cvar[cSqlUsername],szUsername,charsmax(szUsername));
	get_pcvar_string(Cvar[cSqlPassword],szPassword,charsmax(szPassword));
	get_pcvar_string(Cvar[cSqlDatabase],szDatabase,charsmax(szDatabase));
	get_pcvar_string(Cvar[cSqlPrefix],Global[gSzPrefix],charsmax(Global[gSzPrefix]));
	
	get_pcvar_string(Cvar[cSite],Global[gSzSite],charsmax(Global[gSzSite]));
	
	Global[gTimeOffset]=get_pcvar_num(Cvar[cTimeOffset]);
	
	MySql_Init(szHostname,szUsername,szPassword,szDatabase);
	
	GetServerID();
}
public plugin_end() {
	MySql_Close();
}
GetServerID() {
	MySql_Query2("GetServerID_handler",_,_,"SELECT `id` FROM `%s_servers` WHERE `ip` = '%s'",Global[gSzPrefix],Global[gSzServerIP]);
}
public GetServerID_handler(Handle:Query) {
	new iResults=MySql_ResultsNum(Query);
	if(iResults) {
		Global[gServerID]=MySql_ReadResultNum(Query,"id");
		MySql_QueryAndIgnore("UPDATE `%s_servers` SET `version` = '%s', `last_seen` = '%d' WHERE `id` = %d;",Global[gSzPrefix],VERSION,get_systime(Global[gTimeOffset]),Global[gServerID]);
	} else {
		MySql_QueryAndIgnore("INSERT INTO `%s_servers` (`ip`, `version`) VALUES ('%s', '%s');",Global[gSzPrefix],Global[gSzServerIP],VERSION);
		GetServerID();
		return;
	}
	LoadAdmins();
}
public cmdReload() {
	ArrayClear(aAdmins);
	LoadAdmins();
}

LoadAdmins() {
	MySql_Query2("LoadAdmins_handler",_,_,"SELECT `admin`.`auth`, `admin`.`password`,`admin`.`flags`, `level`.`access` FROM `%s_admins` AS `admin`, `%s_levels` AS `level`, `%s_server_admins` AS `server` WHERE `admin`.`id`=`server`.`admin` AND `level`.`id`=`server`.`level` AND `server`.`server`='%d';",Global[gSzPrefix],Global[gSzPrefix],Global[gSzPrefix],Global[gServerID]);
}
public LoadAdmins_handler(Handle:Query) {
	
	new AdminData[AdminDataStruct];
	new szAccess[23];
	new szFlags[5];
	
	for(;MySql_MoreResults(Query);SQL_NextRow(Query)) {
		MySql_ReadResultString(Query,"auth",AdminData[admSzAuth],charsmax(AdminData[admSzAuth]));
		MySql_ReadResultString(Query,"password",AdminData[admSzPassword],charsmax(AdminData[admSzPassword]));
		MySql_ReadResultString(Query,"access",szAccess,charsmax(szAccess));
		MySql_ReadResultString(Query,"flags",szFlags,charsmax(szFlags));
		
		AdminData[admIAccess]=read_flags(szAccess);
		AdminData[admIFlags]=read_flags(szFlags);
		
		ArrayPushArray(aAdmins,AdminData);
	}
	
	server_print("%L",LANG_SERVER,"SQL_LOADED_ADMINS",ArraySize(aAdmins));
}
public client_putinserver(id) {
	remove_user_flags(id);
	new szAuthID[33],szIP[23],szName[33],szPassword[33];
	get_user_authid(id,szAuthID,charsmax(szAuthID));
	get_user_ip(id,szIP,charsmax(szIP),1);
	get_user_name(id,szName,charsmax(szName));
	get_user_info(id,"_pw",szPassword,charsmax(szPassword));
	
	new AdminData[AdminDataStruct];
	new iFlags,szAuth[33],bool:bSelected;
	for(new a=0;a<ArraySize(aAdmins);++a) {
		ArrayGetArray(aAdmins,a,AdminData);
		szAuth=AdminData[admSzAuth];
		iFlags=AdminData[admIFlags];
		
		if(iFlags&FLAG_AUTHID && equal(szAuthID,szAuth)) {bSelected=true;break;}
		else if(iFlags&FLAG_IP && equal(szIP,szAuth)) {bSelected=true;break;}
		else if(iFlags&FLAG_TAG && iFlags&FLAG_CASE_SENSITIVE?contain(szName,szAuth)!=-1:contain(szName,szAuth)!=1) {bSelected=true;break;}
		else if(iFlags&FLAG_CASE_SENSITIVE?equal(szName,szAuth):equali(szName,szAuth)) {bSelected=true;break;}
	}
	if(!bSelected) {
		set_user_flags(id,read_flags("z"));
		return;
	}
	if(iFlags&FLAG_NOPASS || equal(szPassword,AdminData[admSzPassword])) {
		set_user_flags(id,AdminData[admIAccess]);
		client_print(id,print_console,"%L",LANG_PLAYER,"PRIV_SET");
		log_amx("[MegaBans] Login: ^"%s^" <%s><%s> became an admin (access ^"%s^")",szName,szAuthID,szIP,szAuth);
		
	} else if(iFlags&FLAG_KICK) {
		//log_amx("[UBans] Login: ^"%s^" <%s><%s> kicked due to invalid password (account ^"%s^")", name, authid, ip, AuthData);
		//client_cmd(id,"echo * bad password(for admin)");
		//server_cmd("kick #%d ^"%L^"", get_user_userid(id), id, "NO_ENTRY")
		client_print(id,print_console,"%L",LANG_PLAYER,"INV_PAS");
		//kick
	}
}


















