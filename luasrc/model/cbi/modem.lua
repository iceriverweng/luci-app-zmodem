local m, section, m2, s2

m = Map("modem", translate("移动网络"))
section = m:section(TypedSection, "ndis", translate("蜂窝设置"))
section.anonymous = true
section.addremove = false
	section:tab("general", translate("常规设置"))
	section:tab("advanced", translate("高级设置"))

enable = section:taboption("general", Flag, "enable", translate("启用模块"))
enable.rmempty  = false


simsel= section:taboption("general", ListValue, "simsel", translate("SIM卡选择"))
simsel:value("0", translate("外置SIM卡"))
simsel:value("1", translate("内置SIM1"))
simsel:value("2", translate("内置SIM2"))
simsel.rmempty = true

pincode = section:taboption("general", Value, "pincode", translate("PIN密码"))
pincode.readonly = true
------
apnconfig = section:taboption("general", Value, "apnconfig", translate("APN接入点"))
apnconfig.rmempty = true
------------




smode = section:taboption("advanced", ListValue, "smode", translate("网络制式"))
smode.default = "0"
smode:value("0", translate("自动"))
smode:value("1", translate("4G网络"))
smode:value("2", translate("5G网络"))

nrmode = section:taboption("advanced", ListValue, "nrmode", translate("5G模式"))
nrmode:value("0", translate("SA/NSA双模"))
nrmode:value("1", translate("SA模式"))
nrmode:value("2", translate("NSA模式"))
nrmode:depends("smode","2")

bandlist_lte = section:taboption("advanced", ListValue, "bandlist_lte", translate("LTE频段"))
bandlist_lte.default = "0"
bandlist_lte:value("0", translate("自动"))
bandlist_lte:value("1", translate("BAND 1"))
bandlist_lte:value("3", translate("BAND 3"))
bandlist_lte:value("5", translate("BAND 5"))
bandlist_lte:value("8", translate("BAND 8"))
bandlist_lte:value("34", translate("BAND 34"))
bandlist_lte:value("38", translate("BAND 38"))
bandlist_lte:value("39", translate("BAND 39"))
bandlist_lte:value("40", translate("BAND 40"))
bandlist_lte:value("41", translate("BAND 41"))
bandlist_lte:depends("smode","1")

bandlist_sa = section:taboption("advanced", ListValue, "bandlist_sa", translate("5G-SA频段"))
bandlist_sa.default = "0"
bandlist_sa:value("0", translate("自动"))
bandlist_sa:value("1", translate("BAND 1"))
bandlist_sa:value("3", translate("BAND 3"))
bandlist_sa:value("8", translate("BAND 8"))
bandlist_sa:value("28", translate("BAND 28"))
bandlist_sa:value("41", translate("BAND 41"))
bandlist_sa:value("78", translate("BAND 78"))
bandlist_sa:value("79", translate("BAND 79"))
bandlist_sa:depends("nrmode","1")

bandlist_nsa = section:taboption("advanced", ListValue, "bandlist_nsa", translate("5G-NSA频段"))
bandlist_nsa.default = "0"
bandlist_nsa:value("0", translate("自动"))
bandlist_nsa:value("41", translate("BAND 41"))
bandlist_nsa:value("78", translate("BAND 78"))
bandlist_nsa:depends("nrmode","2")

earfcn = section:taboption("advanced", Value, "earfcn", translate("频点锁定"))
earfcn:depends("smode","1")
earfcn:depends("smode","2")
earfcn.readonly = true

cellid = section:taboption("advanced", Value, "cellid", translate("小区锁定"))
cellid:depends("smode","1")
cellid:depends("smode","2")
cellid.readonly = true

enable_imei = section:taboption("advanced", Flag, "enable_imei", translate("修改IMEI"))
enable_imei.default = false
enable_imei:depends("simsel", "0")

modify_imei = section:taboption("advanced", Value, "modify_imei", translate("IMEI"))
modify_imei.default = luci.sys.exec("sendat 2 AT+CGSN| grep -oE '[0-9]+'")
modify_imei:depends("enable_imei", "1")
modify_imei.validate = function(self, value)
    if not value:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
        return nil, translate("IMEI必须是15位数字")
    end
    return value
end


s2 = m:section(TypedSection, "ndis", translate("网络检测"), translate("Ping一个指定地址 失败则重启网络接口 多次尝试无效则会退出检测"))
s2.anonymous = true
s2.addremove = false

en = s2:option(Flag, "pingen", translate("启用"))
en.rmempty = false

ipaddress= s2:option(Value, "pingaddr", translate("Ping地址"))
ipaddress.rmempty=false

an = s2:option(Value, "count", translate("检测间隔(秒)"))
an.default = "5"
an:value("5", "5")
an:value("10", "10")
an:value("15", "15")
an.rmempty=false

local apply = luci.http.formvalue("cbi.apply")
if apply then
    io.popen("/usr/share/modem/rm520n.sh &")
end

return m,m2
