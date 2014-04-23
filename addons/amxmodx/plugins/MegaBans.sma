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
	admIAccess,
	admSzPassword[33]
}

new Cvar[CvarStruct];
new Global[GlobalStruct];

new Trie:tAdmins;

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
	
	tAdmins=TrieCreate();
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
		MySql_QueryAndIgnore("UPDATE `%s_servers` SET `version` = '%s' WHERE `id` = %d;",Global[gSzPrefix],VERSION,Global[gServerID]);
	} else {
		MySql_QueryAndIgnore("INSERT INTO `%s_servers` (`ip`, `version`) VALUES ('%s', '%s');",Global[gSzPrefix],Global[gSzServerIP],VERSION);
		GetServerID();
		return;
	}
	LoadAdmins();
}
LoadAdmins() {
	MySql_Query2("LoadAdmins_handler",_,_,"SELECT `admin`.`auth`, `level`.`access` FROM `%s_admins` AS `admin`, `%s_levels` AS `level`, `%s_server_admins` AS `server` WHERE `admin`.`id`=`server`.`admin` AND `level`.`id`=`server`.`level` AND `server`.`server`='%d';",Global[gSzPrefix],Global[gSzPrefix],Global[gSzPrefix],Global[gServerID]);
}
public LoadAdmins_handler(Handle:Query) {
	
	new szAuth[33],AdminData[AdminDataStruct],szAccess[23];
	
	for(;MySql_MoreResults(Query);SQL_NextRow(Query)) {
		MySql_ReadResultString(Query,"auth",szAuth,charsmax(szAuth));
		
		MySql_ReadResultString(Query,"access",szAccess,charsmax(szAccess));
		
		//MySql_ReadResultString(Query,"password",AdminData[admSzPassword],charsmax(AdminData[admSzPassword]));
		
		AdminData[admIAccess]=read_flags(szAccess);
		
		TrieSetArray(tAdmins,szAuth,AdminData,sizeof(AdminData));
	}
}
public client_authorized(id) {
	new szAuthID[33],szIP[23],szName[33];
	get_user_authid(id,szAuthID,charsmax(szAuthID));
	get_user_ip(id,szIP,charsmax(szIP),1);
	get_user_name(id,szName,charsmax(szName));
	
	
}
public client_putinserver(id) {
	new szAuthID[33],szIP[23],szName[33];
	get_user_authid(id,szAuthID,charsmax(szAuthID));
	get_user_ip(id,szIP,charsmax(szIP),1);
	get_user_name(id,szName,charsmax(szName));
	
	new AdminData[AdminDataStruct];
	
	if(
	TrieKeyExists(tAdmins,szAuthID)) {
		TrieGetArray(tAdmins,szAuthID,AdminData,sizeof(AdminData));
	} else if(
	TrieKeyExists(tAdmins,szIP)) {
		TrieGetArray(tAdmins,szIP,AdminData,sizeof(AdminData));
	} else if(
	TrieKeyExists(tAdmins,szName)) {
		TrieGetArray(tAdmins,szName,AdminData,sizeof(AdminData));
	} else return;
	
	//if(1=1)
	
	set_user_flags(id,AdminData[admIAccess]);
}


















