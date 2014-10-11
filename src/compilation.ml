open Def;
value (wd, d, h) = (4, {day=04;month=09;year=2014;prec=Sure;delta=0}, "11:37:13 CEST");
value ct conf = Printf.sprintf " (%4d-%02d-%02d %s)" d.year d.month d.day h;
Util.compilation_time_hook.val := ct;
