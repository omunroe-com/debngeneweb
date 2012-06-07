open Def;
value (wd, d, h) = (2, {day=05;month=06;year=2012;prec=Sure;delta=0}, "08:59:42 CEST");
value ct conf = Printf.sprintf " (%4d-%02d-%02d %s)" d.year d.month d.day h;
Util.compilation_time_hook.val := ct;
