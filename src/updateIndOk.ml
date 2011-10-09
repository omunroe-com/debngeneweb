(* camlp5r ./pa_html.cmo *)
(* $Id: updateIndOk.ml,v 5.75 2008-01-21 13:28:12 ddr Exp $ *)
(* Copyright (c) 1998-2007 INRIA *)

open Config;
open Def;
open Futil;
open Gutil;
open Gwdb;
open Hutil;
open Mutil;
open Util;

value raw_get conf key =
  match p_getenv conf.env key with
  [ Some v -> v
  | None -> failwith (key ^ " unbound") ]
;

value get conf key =
  match p_getenv conf.env key with
  [ Some v -> v
  | None -> failwith (key ^ " unbound") ]
;

value get_nth conf key cnt = p_getenv conf.env (key ^ string_of_int cnt);

value getn conf var key =
  match p_getenv conf.env (var ^ "_" ^ key) with
  [ Some v -> v
  | None -> failwith (var ^ "_" ^ key ^ " unbound") ]
;

value rec reconstitute_string_list conf var ext cnt =
  match get_nth conf var cnt with
  [ Some s ->
      let s = no_html_tags (only_printable s) in
      let (sl, ext) = reconstitute_string_list conf var ext (cnt + 1) in
      match get_nth conf ("add_" ^ var) cnt with
      [ Some "on" -> ([s; "" :: sl], True)
      | _ -> ([s :: sl], ext) ]
  | _ -> ([], ext) ]
;

value reconstitute_insert_title conf ext cnt tl =
  let var = "ins_title" ^ string_of_int cnt in
  let n =
    match (p_getenv conf.env var, p_getint conf.env (var ^ "_n")) with
    [ (_, Some n) when n > 1 -> n
    | (Some "on", _) -> 1
    | _ -> 0 ]
  in
  if n > 0 then
    let tl =
      loop tl n where rec loop tl n =
        if n > 0 then
          let t1 =
            {t_name = Tnone; t_ident = ""; t_place = "";
             t_date_start = Adef.codate_None; t_date_end = Adef.codate_None;
             t_nth = 0}
          in
          loop [t1 :: tl] (n - 1)
        else tl
    in
    (tl, True)
  else (tl, ext)
;

value rec reconstitute_titles conf ext cnt =
  match
    (get_nth conf "t_ident" cnt, get_nth conf "t_place" cnt,
     get_nth conf "t_name" cnt)
  with
  [ (Some t_ident, Some t_place, Some t_name) ->
      let t_name =
        match (get_nth conf "t_main_title" cnt, t_name) with
        [ (Some "on", _) -> Tmain
        | (_, "") -> Tnone
        | (_, _) -> Tname (no_html_tags (only_printable t_name)) ]
      in
      let t_date_start =
        Update.reconstitute_date conf ("t_date_start" ^ string_of_int cnt)
      in
      let t_date_end =
        Update.reconstitute_date conf ("t_date_end" ^ string_of_int cnt)
      in
      let t_nth =
        match get_nth conf "t_nth" cnt with
        [ Some s -> try int_of_string s with [ Failure _ -> 0 ]
        | _ -> 0 ]
      in
      let t =
        {t_name = t_name; t_ident = no_html_tags (only_printable t_ident);
         t_place = no_html_tags (only_printable t_place);
         t_date_start = Adef.codate_of_od t_date_start;
         t_date_end = Adef.codate_of_od t_date_end; t_nth = t_nth}
      in
      let (tl, ext) = reconstitute_titles conf ext (cnt + 1) in
      let (tl, ext) = reconstitute_insert_title conf ext cnt tl in
      ([t :: tl], ext)
  | _ -> ([], ext) ]
;

value reconstitute_add_relation conf ext cnt rl =
  match get_nth conf "add_relation" cnt with
  [ Some "on" ->
      let r =
        {r_type = Adoption; r_fath = None; r_moth = None; r_sources = ""}
      in
      ([r :: rl], True)
  | _ -> (rl, ext) ]
;

value reconstitute_relation_parent conf var key sex =
  match (getn conf var (key ^ "_fn"), getn conf var (key ^ "_sn")) with
  [ ("", _) | ("?", _) | (_, "?") -> None
  | (fn, sn) ->
      let fn = only_printable fn in
      let sn = only_printable sn in
      let occ =
        try int_of_string (getn conf var (key ^ "_occ")) with
        [ Failure _ -> 0 ]
      in
      let create =
        match getn conf var (key ^ "_p") with
        [ "create" -> Update.Create sex None
        | _ -> Update.Link ]
      in
      Some (fn, sn, occ, create, var ^ "_" ^ key) ]
;

value reconstitute_relation conf var =
  try
    let r_fath = reconstitute_relation_parent conf var "fath" Male in
    let r_moth = reconstitute_relation_parent conf var "moth" Female in
    let r_type =
      match getn conf var "type" with
      [ "Adoption" -> Adoption
      | "Recognition" -> Recognition
      | "CandidateParent" -> CandidateParent
      | "GodParent" -> GodParent
      | "FosterParent" -> FosterParent
      | _ -> Adoption ]
    in
    Some {r_type = r_type; r_fath = r_fath; r_moth = r_moth; r_sources = ""}
  with
  [ Failure _ -> None ]
;

value rec reconstitute_relations conf ext cnt =
  match reconstitute_relation conf ("r" ^ string_of_int cnt) with
  [ Some r ->
      let (rl, ext) = reconstitute_relations conf ext (cnt + 1) in
      let (rl, ext) = reconstitute_add_relation conf ext cnt rl in
      ([r :: rl], ext)
  | _ -> ([], ext) ]
;

value reconstitute_death conf birth death_place burial burial_place =
  let d = Update.reconstitute_date conf "death" in
  let dr =
    match p_getenv conf.env "death_reason" with
    [ Some "Killed" -> Killed
    | Some "Murdered" -> Murdered
    | Some "Executed" -> Executed
    | Some "Disappeared" -> Disappeared
    | Some "Unspecified" | None -> Unspecified
    | Some x -> failwith ("bad death reason type " ^ x) ]
  in
  match get conf "death" with
  [ "Auto" when d = None ->
      if death_place <> "" || burial <> UnknownBurial || burial_place <> "" ||
         dr <> Unspecified then
        DeadDontKnowWhen
      else Update.infer_death conf birth
  | "DeadYoung" when d = None -> DeadYoung
  | "DontKnowIfDead" when d = None -> DontKnowIfDead
  | "NotDead" -> NotDead
  | "OfCourseDead" -> OfCourseDead
  | _ ->
      match d with
      [ Some d -> Death dr (Adef.cdate_of_date d)
      | _ -> DeadDontKnowWhen ] ]
;

value reconstitute_burial conf burial_place =
  let d = Update.reconstitute_date conf "burial" in
  match p_getenv conf.env "burial" with
  [ Some "UnknownBurial" | None ->
      match (d, burial_place) with
      [ (None, "") -> UnknownBurial
      | _ -> Buried (Adef.codate_of_od d) ]
  | Some "Buried" -> Buried (Adef.codate_of_od d)
  | Some "Cremated" -> Cremated (Adef.codate_of_od d)
  | Some x -> failwith ("bad burial type " ^ x) ]
;

value reconstitute_person conf =
  let ext = False in
  let key_index =
    match p_getenv conf.env "i" with
    [ Some s -> try int_of_string (strip_spaces s) with [ Failure _ -> -1 ]
    | _ -> -1 ]
  in
  let first_name = no_html_tags (only_printable (get conf "first_name")) in
  let surname = no_html_tags (only_printable (get conf "surname")) in
  let occ =
    try int_of_string (strip_spaces (get conf "occ")) with [ Failure _ -> 0 ]
  in
  let image = only_printable (get conf "image") in
  let (first_names_aliases, ext) =
    reconstitute_string_list conf "first_name_alias" ext 0
  in
  let (surnames_aliases, ext) =
    reconstitute_string_list conf "surname_alias" ext 0
  in
  let public_name = no_html_tags (only_printable (get conf "public_name")) in
  let (qualifiers, ext) = reconstitute_string_list conf "qualifier" ext 0 in
  let (aliases, ext) = reconstitute_string_list conf "alias" ext 0 in
  let (titles, ext) = reconstitute_titles conf ext 1 in
  let (titles, ext) = reconstitute_insert_title conf ext 0 titles in
  let (rparents, ext) = reconstitute_relations conf ext 1 in
  let (rparents, ext) = reconstitute_add_relation conf ext 0 rparents in
  let access =
    match p_getenv conf.env "access" with
    [ Some "Public" -> Public
    | Some "Private" -> Private
    | _ -> IfTitles ]
  in
  let occupation = only_printable (get conf "occu") in
  let sex =
    match p_getenv conf.env "sex" with
    [ Some "M" -> Male
    | Some "F" -> Female
    | _ -> Neuter ]
  in
  let birth = Update.reconstitute_date conf "birth" in
  let birth_place = only_printable (get conf "birth_place") in
  let bapt = Adef.codate_of_od (Update.reconstitute_date conf "bapt") in
  let bapt_place = only_printable (get conf "bapt_place") in
  let burial_place = only_printable (get conf "burial_place") in
  let burial = reconstitute_burial conf burial_place in
  let death_place = only_printable (get conf "death_place") in
  let death = reconstitute_death conf birth death_place burial burial_place in
  let death_place =
    match death with
    [ Death _ _ | DeadYoung | DeadDontKnowWhen -> death_place
    | _ -> "" ]
  in
  let death =
    match (death, burial) with
    [ (NotDead | DontKnowIfDead, Buried _ | Cremated _) -> DeadDontKnowWhen
    | _ -> death ]
  in
  let notes =
    if first_name = "?" || surname = "?" then ""
    else only_printable_or_nl (strip_all_trailing_spaces (get conf "notes"))
  in
  let psources = only_printable (get conf "src") in
  let p =
    {first_name = first_name; surname = surname; occ = occ; image = image;
     first_names_aliases = first_names_aliases;
     surnames_aliases = surnames_aliases; public_name = public_name;
     qualifiers = qualifiers; aliases = aliases; titles = titles;
     rparents = rparents; occupation = occupation; related = []; sex = sex;
     access = access; birth = Adef.codate_of_od birth;
     birth_place = birth_place;
     birth_src = only_printable (get conf "birth_src"); baptism = bapt;
     baptism_place = bapt_place;
     baptism_src = only_printable (get conf "bapt_src"); death = death;
     death_place = death_place;
     death_src = only_printable (get conf "death_src"); burial = burial;
     burial_place = burial_place;
     burial_src = only_printable (get conf "burial_src");
     notes = notes; psources = psources;
     key_index = Adef.iper_of_int key_index}
  in
  (p, ext)
;

value check_person conf base p =
  if p.first_name = "" || p.first_name = "?" then
    Some (transl conf "first name missing")
  else if p.surname = "" || p.surname = "?" then
    Some (transl conf "surname missing")
  else None
;

value error_person conf base p err =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title; Wserver.wprint "%s\n" (capitale err); trailer conf;
  }
;

value strip_list = List.filter (fun s -> s <> "");

value strip_person p =
  {(p) with
   first_names_aliases = strip_list p.first_names_aliases;
   surnames_aliases = strip_list p.surnames_aliases;
   qualifiers = strip_list p.qualifiers;
   aliases = strip_list p.aliases;
   titles = List.filter (fun t -> t.t_ident <> "") p.titles;
   rparents =
     List.filter (fun r -> r.r_fath <> None || r.r_moth <> None) p.rparents}
;

value print_conflict conf base p =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    Update.print_error conf base (AlreadyDefined p);
    html_p conf;
    let free_n =
      Gutil.find_free_occ base (p_first_name base p) (p_surname base p) 0
    in
    tag "ul" begin
      html_li conf;
      Wserver.wprint "%s: %d.\n" (capitale (transl conf "first free number"))
        free_n;
      Wserver.wprint (fcapitale (ftransl conf "click on \"%s\""))
        (transl conf "create");
      Wserver.wprint "%s.\n" (transl conf " to try again with this number");
      html_li conf;
      Wserver.wprint "%s " (capitale (transl conf "or"));
      Wserver.wprint (ftransl conf "click on \"%s\"") (transl conf "back");
      Wserver.wprint " %s %s." (transl_nth conf "and" 0)
        (transl conf "change it (the number) yourself");
    end;
    html_p conf;
    tag "form" "method=\"post\" action=\"%s\"" conf.command begin
      List.iter
        (fun (x, v) ->
           Wserver.wprint "<input type=\"hidden\" name=\"%s\" value=\"%s\">\n" x
             (quote_escaped (decode_varenv v)))
        (conf.henv @ conf.env);
      Wserver.wprint "<input type=\"hidden\" name=\"free_occ\" value=\"%d\">\n"
        free_n;
      Wserver.wprint "<input type=\"submit\" name=\"create\" value=\"%s\">\n"
        (capitale (transl conf "create"));
      Wserver.wprint "<input type=\"submit\" name=\"return\" value=\"%s\">\n"
        (capitale (transl conf "back"));
    end;
    Update.print_same_name conf base p;
    trailer conf;
    raise Update.ModErr
  }
;

value print_cannot_change_sex conf base p =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "error")) in
  do {
    rheader conf title;
    Update.print_error conf base (BadSexOfMarriedPerson p);
    tag "ul" begin
      html_li conf;
      Wserver.wprint "\n%s" (referenced_person_text conf base p);
      Wserver.wprint "\n";
    end;
    Update.print_return conf;
    trailer conf;
    raise Update.ModErr
  }
;

value check_conflict conf base sp ipl =
  let name = Name.lower (sp.first_name ^ " " ^ sp.surname) in
  List.iter
    (fun ip ->
       let p1 = poi base ip in
       if get_key_index p1 <> sp.key_index &&
          Name.lower (p_first_name base p1 ^ " " ^ p_surname base p1) =
            name &&
          get_occ p1 = sp.occ then
         print_conflict conf base p1
       else ())
    ipl
;

value check_sex_married conf base sp op =
  if sp.sex <> get_sex op then
    let no_check =
      List.for_all
        (fun ifam ->
           let r = get_relation (foi base ifam) in
           r = NoSexesCheckNotMarried || r = NoSexesCheckMarried)
        (Array.to_list (get_family op))
    in
    if no_check then () else print_cannot_change_sex conf base op
  else ()
;

value rename_image_file conf base op sp =
  match auto_image_file conf base op with
  [ Some old_f ->
      let s = default_image_name_of_key sp.first_name sp.surname sp.occ in
      let f = Filename.concat (Util.base_path ["images"] conf.bname) s in
      let new_f =
        if Filename.check_suffix old_f ".gif" then f ^ ".gif" else f ^ ".jpg"
      in
      try Sys.rename old_f new_f with [ Sys_error _ -> () ]
  | _ -> () ]
;

value rparents_of rparents =
  List.fold_left
    (fun ipl r ->
       match (r.r_fath, r.r_moth) with
       [ (Some ip1, Some ip2) -> [ip1; ip2 :: ipl]
       | (Some ip, _) -> [ip :: ipl]
       | (_, Some ip) -> [ip :: ipl]
       | _ -> ipl ])
    [] rparents
;

value is_witness_at_marriage base ip p =
  let u = poi base ip in
  List.exists
    (fun ifam -> let fam = foi base ifam in array_mem ip (get_witnesses fam))
    (Array.to_list (get_family u))
;

value effective_mod conf base sp = do {
  let pi = sp.key_index in
  let op = poi base pi in
  let key = sp.first_name ^ " " ^ sp.surname in
  let ofn = p_first_name base op in
  let osn = p_surname base op in
  let oocc = get_occ op in
  if ofn = sp.first_name && osn = sp.surname && oocc = sp.occ then ()
  else do {
    let ipl = person_ht_find_all base key in
    check_conflict conf base sp ipl;
    rename_image_file conf base op sp;
  };
  let same_fn_sn =
    Name.lower (nominative sp.first_name) = Name.lower ofn &&
    Name.lower (nominative sp.surname) = Name.lower osn
  in
  if sp.first_name <> "?" && sp.surname <> "?" &&
     (not same_fn_sn || oocc <> sp.occ)
  then do {
    delete_key base ofn osn oocc;
    patch_key base pi sp.first_name sp.surname sp.occ;
    if not same_fn_sn then patch_name base key pi else ();
  }
  else ();
  check_sex_married conf base sp op;
  let created_p = ref [] in
  let np =
    map_person_ps (Update.insert_person conf base sp.psources created_p)
      (Gwdb.insert_string base) sp
  in
  let op_misc_names = person_misc_names base op get_titles in
  let np = {(np) with related = get_related op} in
  let np_misc_names = gen_person_misc_names base np (fun p -> p.titles) in
  List.iter
    (fun key ->
       if List.mem key op_misc_names then () else person_ht_add base key pi)
    np_misc_names;
  let ol = rparents_of (get_rparents op) in
  let nl = rparents_of np.rparents in
  let pi = np.key_index in
  Update.update_related_pointers base pi ol nl;
  np
};

value effective_add conf base sp = do {
  let pi = Adef.iper_of_int (nb_of_persons base) in
  let fn = Util.translate_eval sp.first_name in
  let sn = Util.translate_eval sp.surname in
  let key = fn ^ " " ^ sn in
  let ipl = person_ht_find_all base key in
  check_conflict conf base sp ipl;
  patch_key base pi fn sn sp.occ;
  person_ht_add base key pi;
  let created_p = ref [] in
  let np =
    map_person_ps (Update.insert_person conf base sp.psources created_p)
      (Gwdb.insert_string base) {(sp) with key_index = pi}
  in
  patch_person base pi np;
  let na = {parents = None; consang = Adef.fix (-1)} in
  patch_ascend base pi na;
  let nu = {family = [| |]} in
  patch_union base pi nu;
  let np_misc_names = gen_person_misc_names base np (fun p -> p.titles) in
  List.iter (fun key -> person_ht_add base key pi) np_misc_names;
  (np, na)
};

value array_except v a =
  loop 0 where rec loop i =
    if i = Array.length a then a
    else if a.(i) = v then
      Array.append (Array.sub a 0 i)
        (Array.sub a (i + 1) (Array.length a - i - 1))
    else loop (i + 1)
;

value update_relations_of_related base ip old_related =
  List.iter
    (fun ip1 -> do {
       let p1 = poi base ip1 in
       let (rparents, rparents_are_different) =
         List.fold_right
           (fun rel (list, rad) ->
              let (rfath, rad) =
                match rel.r_fath with
                [ Some ip2 ->
                    if ip2 = ip then (None, True) else (Some ip2, rad)
                | None -> (None, rad) ]
              in
              let (rmoth, rad) =
                match rel.r_moth with
                [ Some ip2 ->
                    if ip2 = ip then (None, True) else (Some ip2, rad)
                | None -> (None, rad) ]
              in
              if rfath = None && rmoth = None then (list, True)
              else
                let rel = {(rel) with r_fath = rfath; r_moth = rmoth} in
                ([rel :: list], rad))
           (get_rparents p1) ([], False)
       in
       if rparents_are_different then
         let p = gen_person_of_person p1 in
         patch_person base ip1 {(p) with rparents = rparents}
       else ();
       let families = get_family p1 in
       for i = 0 to Array.length families - 1 do {
         let ifam = families.(i) in
         let fam = foi base ifam in
         let old_witnesses = Array.to_list (get_witnesses fam) in
         let new_witnesses = List.filter (\<> ip) old_witnesses in
         if new_witnesses <> old_witnesses then
           let fam = gen_family_of_family fam in
           patch_family base ifam
             {(fam) with witnesses = Array.of_list new_witnesses}
         else ();
       };
     })
    old_related
;

value effective_del conf base warning p = do {
  let none = Gwdb.insert_string base "?" in
  let empty = Gwdb.insert_string base "" in
  let ip = get_key_index p in
  match get_parents p with
  [ Some ifam -> do {
      let des = foi base ifam in
      let des = do {
        let children = array_except ip (get_children des) in
        match CheckItem.sort_children base children with
        [ Some (b, a) -> warning (ChangedOrderOfChildren ifam des b a)
        | None -> () ];
        {children = children}
      }
      in
      patch_descend base ifam des;
      let asc = {parents = None; consang = Adef.fix (-1)} in
      patch_ascend base ip asc;
    }
  | None -> () ];
  let old_rparents = rparents_of (get_rparents p) in
  Update.update_related_pointers base ip old_rparents [];
  {first_name = none; surname = none; occ = 0; image = empty;
   public_name = empty; qualifiers = []; aliases = []; sex = get_sex p;
   first_names_aliases = []; surnames_aliases = []; titles = [];
   rparents = []; related = []; occupation = empty; access = IfTitles;
   birth = Adef.codate_None; birth_place = empty; birth_src = empty;
   baptism = Adef.codate_None; baptism_place = empty; baptism_src = empty;
   death = DontKnowIfDead; death_place = empty; death_src = empty;
   burial = UnknownBurial; burial_place = empty; burial_src = empty;
   notes = empty; psources = empty; key_index = ip}
};

value print_mod_ok conf base wl p =
  let title _ =
    Wserver.wprint "%s" (capitale (transl conf "person modified"))
  in
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "\n%s"
      (referenced_person_text conf base (poi base p.key_index));
    Wserver.wprint "\n";
    Update.print_warnings conf base wl;
    trailer conf;
  }
;

(*
value print_mod_ok conf base wl p =
  if wl = [] then Perso.print conf base p
  else print_mod_ok_aux conf base wl p
;
*)

value relation_sex_is_coherent base warning p =
  List.iter
    (fun r ->
       do {
         match r.r_fath with
         [ Some ip ->
             let p = poi base ip in
             if get_sex p <> Male then warning (IncoherentSex p 0 0) else ()
         | None -> () ];
         match r.r_moth with
         [ Some ip ->
             let p = poi base ip in
             if get_sex p <> Female then warning (IncoherentSex p 0 0) else ()
         | None -> () ];
       })
    p.rparents
;

value all_checks_person conf base p a u = do {
  let wl = ref [] in
  let error = Update.error conf base in
  let warning w = wl.val := [w :: wl.val] in
  let _ : option _ =
    let p = person_of_gen_person base (p, a, u) in
    CheckItem.person base warning p
  in
  relation_sex_is_coherent base warning p;
  match a.parents with
  [ Some ifam -> CheckItem.family base error warning ifam (foi base ifam)
  | _ -> () ];
  Array.iter
    (fun ifam -> CheckItem.family base error warning ifam (foi base ifam))
    u.family;
  List.iter
    (fun
     [ ChangedOrderOfChildren ifam des _ after ->
         patch_descend base ifam {children = after}
     | _ -> () ])
    wl.val;
  List.rev wl.val
};

value print_add_ok conf base wl p =
  let title _ = Wserver.wprint "%s" (capitale (transl conf "person added")) in
  do {
    header conf title;
    print_link_to_welcome conf True;
    Wserver.wprint "\n%s"
      (referenced_person_text conf base (poi base p.key_index));
    Wserver.wprint "\n";
    Update.print_warnings conf base wl;
    trailer conf;
  }
;

(*
value print_add_ok conf base wl p =
  if wl = [] then Perso.print conf base p
  else print_add_ok_aux conf base wl p
;
*)

value print_del_ok conf base wl =
  let title _ =
    Wserver.wprint "%s" (capitale (transl conf "person deleted"))
  in
  do {
    header conf title;
    print_link_to_welcome conf False;
    Update.print_warnings conf base wl;
    trailer conf;
  }
;

value print_add o_conf base =
  let conf = Update.update_conf o_conf in
  try
    let (sp, ext) = reconstitute_person conf in
    let redisp =
      match p_getenv conf.env "return" with
      [ Some _ -> True
      | _ -> False ]
    in
    if ext || redisp then UpdateInd.print_update_ind conf base sp ""
    else do {
      let sp = strip_person sp in
      match check_person conf base sp with
      [ Some err -> error_person conf base sp err
      | None ->
          let (p, a) = effective_add conf base sp in
          let u = {family = get_family (poi base p.key_index)} in
          let wl = all_checks_person conf base p a u in
          let k = (sp.first_name, sp.surname, sp.occ, p.key_index) in
          do {
            Util.commit_patches conf base;
            History.record conf base k "ap";
            print_add_ok conf base wl p;
          } ]
    }
  with
  [ Update.ModErr -> () ]
;

value print_del conf base =
  match p_getint conf.env "i" with
  [ Some i -> do {
      let ip = Adef.iper_of_int i in
      let p = poi base ip in
      let fn = sou base (get_first_name p) in
      let sn = sou base (get_surname p) in
      let occ = get_occ p in
      let k = (fn, sn, occ, ip) in
      let old_related = get_related p in
      update_relations_of_related base ip old_related;
      let warning _ = () in
      let p = effective_del conf base warning p in
      patch_person base ip p;
      delete_key base fn sn occ;
      Notes.update_notes_links_db conf (NotesLinks.PgInd p.key_index) "";
      Util.commit_patches conf base;
      History.record conf base k "dp";
      print_del_ok conf base [];
    }
  | _ -> incorrect_request conf ]
;

value print_mod_aux conf base callback =
  try
    let (p, ext) = reconstitute_person conf in
    let redisp =
      match p_getenv conf.env "return" with
      [ Some _ -> True
      | _ -> False ]
    in
    let ini_ps = UpdateInd.string_person_of base (poi base p.key_index) in
    let digest = Update.digest_person ini_ps in
    if digest = raw_get conf "digest" then
      if ext || redisp then UpdateInd.print_update_ind conf base p digest
      else do {
        let p = strip_person p in
        match check_person conf base p with
        [ Some err -> error_person conf base p err
        | None -> callback p ]
      }
    else Update.error_digest conf
  with
  [ Update.ModErr -> () ]
;

value get_old_key conf base =
  let ip = 
    match p_getenv conf.env "i" with
    [ Some s -> try int_of_string (strip_spaces s) with [ Failure _ -> -1 ]
    | _ -> -1 ]
  in
  let p = poi base (Adef.iper_of_int ip) in
  let first_name = sou base (Gwdb.get_first_name p) in
  let surname = sou base (Gwdb.get_surname p) in
  let occ = Gwdb.get_occ p in
  default_image_name_of_key first_name surname occ
;

value print_mod o_conf base =
  let old_key = get_old_key o_conf base in
  let conf = Update.update_conf o_conf in
  let callback sp = do {
    let p = effective_mod conf base sp in
    let op = poi base p.key_index in
    let u = {family = get_family op} in
    patch_person base p.key_index p;
    let s =
      let sl =
        [p.notes; p.occupation; p.birth_src; p.baptism_src; p.death_src;
         p.burial_src; p.psources]
      in
      String.concat " " (List.map (sou base) sl)
    in
    Notes.update_notes_links_db conf (NotesLinks.PgInd p.key_index) s;
    if not (eq_istr (get_surname op) p.surname) ||
       not (eq_lists eq_istr (get_surnames_aliases op) p.surnames_aliases) ||
       not (eq_lists (eq_titles eq_istr) (get_titles op) p.titles)
    then
      Update.update_misc_names_of_family base p.sex u
    else ();
    let wl =
      let a = poi base p.key_index in
      let a = {parents = get_parents a; consang = get_consang a} in
      all_checks_person conf base p a u
    in
    let k = (sp.first_name, sp.surname, sp.occ, sp.key_index) in
    Util.commit_patches conf base;
    History.record conf base k "mp";
    let new_key = default_image_name_of_key sp.first_name sp.surname sp.occ in
    History.record_key conf base old_key new_key ;
    if not (is_quest_string p.surname) &&
       not (is_quest_string p.first_name) &&
       not (is_old_person conf p)
    then
      Update.delete_topological_sort_v conf base
    else ();
    print_mod_ok conf base wl p;
  }
  in
  print_mod_aux conf base callback
;