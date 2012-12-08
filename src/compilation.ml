open Def;
value (wd, d, h) = (1, {day=03;month=12;year=2012;prec=Sure;delta=0}, "09:10:03 CET");
value ct conf = Printf.sprintf " (%4d-%02d-%02d %s)" d.year d.month d.day h;
Util.compilation_time_hook.val := ct;
