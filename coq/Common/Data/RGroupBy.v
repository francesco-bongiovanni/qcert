(*
 * Copyright 2015-2016 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

Section RGroupBy.
  Require Import List.
  Require Import Utils.
  Require Import RDomain.
  Require Import RData.
  Require Import ForeignData.
  Require Import RRelation.

  Context {fdata:foreign_data}.

  Fixpoint add_in_groups (key: data) (d: data) (l: list (data * (list data))) : list (data * (list data)) :=
    match l with
    | nil =>  (key, (d :: nil)) :: nil
    | (key', group) :: l' =>
      if data_eq_dec key key'
      then
        (key', d::group) :: l'
      else
        let l'' := add_in_groups key d l' in
        (key', group) :: l''
    end.

  (* Primary semantics from Louis *)

  Definition group_by_iter_eval (get_key: data -> option data) (l: list data) : option (list (data * (list data))) :=
    fold_right
      (fun d acc =>
         match acc with
         | Some acc' => lift (fun k => add_in_groups k d acc') (get_key d)
         | None => None
         end)
      (Some nil) l.

  Definition group_by_iter_eval_alt (l: list (data * data)) : list (data * (list data)) :=
    fold_right
      (fun (d:data*data) acc => add_in_groups (fst d) (snd d) acc)
      nil l.

  (* Alternate semantics, using nested loop -- closer to NRC encoding of group by *)

  (* Note: split the proof in two:
       - define a nested-loop based group-by
       - prove that nested-loop based group-by is equivalent to Louis' group-by
       - prove that nested NRC group-by is same as nested-loop group-by
   *)

  (* key eval. there are really two forms. one form is symmetric,
     while the other works when the key computation has been split in two
     phases. which one to use depends on the group-by algorithm *)

  Definition key_is_eq (eval_key: data -> option data) (d1 d2:data) : option bool :=
    olift2 (fun x y => if data_eq_dec x y then Some true else Some false)
           (eval_key d1)
           (eval_key d2).

  Definition key_is_eq_r (eval_key: data -> option data) (d1 d2:data) : option bool :=
    olift2 (fun x y => if data_eq_dec x y then Some true else Some false)
           (eval_key d1)
           (Some d2).

  Lemma key_is_eq_with_project_eq sl d l :
    key_is_eq_r
      (fun d0 : data =>
         match d0 with
         | dunit => None
         | dnat _ => None
         | dbool _ => None
         | dstring _ => None
         | dcoll _ => None
         | drec r => Some (drec (rproject r sl))
         | dleft _ => None
         | dright _ => None
         | dbrand _ _ => None
         | dforeign _ => None
         end) (drec l) d =
    Some (if data_eq_dec (drec (rproject l sl)) d then true else false).
  Proof.
    unfold key_is_eq_r.
    Opaque data_eq_dec.
    simpl.
    destruct (data_eq_dec (drec (rproject l sl)) d); reflexivity.
  Qed.

  Require Import String.
  
  Definition group_of_key (eval_key: data -> option data) (k:data) (l: list data) :=
    (lift_filter (fun d => key_is_eq_r eval_key d k) l).

  Definition group_by_nested_eval (eval_key: data -> option data) (l: list data) : option (list (data * (list data))) :=
    let dupkeys := rmap (fun d => eval_key d) l in
    let keys := lift bdistinct dupkeys in
    olift (rmap (fun k => olift (fun group => Some (k, group)) (group_of_key eval_key k l))) keys.

  Definition to_kv (l: list (data * list data)) :=
    map (fun x => drec (("key"%string,(fst x))::("value"%string,dcoll (snd x)) :: nil)) l.
  
  Definition group_by_nested_eval_kv (eval_key:data -> option data) (l: list data) : option (list data) :=
    lift to_kv (group_by_nested_eval eval_key l).

  (* This will be the harder lemma ... both group-by algorithms are equivalent *)
  (*
  Lemma add_group_same_as_nested_group_by ck l:
    group_by_nested_eval ck l = group_by_iter_eval ck l.
  Proof.
    unfold group_by_nested_eval, group_by_iter_eval.
    induction l; try reflexivity; simpl.
    ...
  Qed.
  *)

  Definition group_to_partitions (g:string) (group: data * list data) : option data :=
    match (fst group) with
    | drec keys =>
      Some (drec (rec_sort ((g,(dcoll (snd group)))::keys)))
    | _ => None
    end.

  Definition to_partitions (g:string) (l: list (data * list data)) :=
    lift_map (group_to_partitions g) l.
  
  Definition group_by_nested_eval_keys_partition
             (g:string) (eval_keys:data -> option data) (l: list data) : option (list data) :=
    olift (to_partitions g) (group_by_nested_eval eval_keys l).

  Section tableform.
    Definition group_by_nested_eval_table
               (g:string) (sl:list string) (l:list data) : option (list data) :=
      group_by_nested_eval_keys_partition
        g
        (fun d =>
           match d with
           | drec r => Some (drec (rproject r sl))
           | _ => None
           end) l.

    Lemma group_of_key_over_table_correct sl d incoll :
      olift (fun group : list data => Some (dcoll group))
            (group_of_key
               (fun d : data =>
                  match d with
                  | dunit => None
                  | dnat _ => None
                  | dbool _ => None
                  | dstring _ => None
                  | dcoll _ => None
                  | drec r => Some (drec (rproject r sl))
                  | dleft _ => None
                  | dright _ => None
                  | dbrand _ _ => None
                  | dforeign _ => None
                  end) d incoll)
      =
(olift
              (fun d1 : data =>
               lift_oncoll
                 (fun l2 : list data => lift dcoll (rflatten l2)) d1)
              (lift dcoll
                 (rmap
                    (fun d1 : data =>
                     olift
                       (fun d0 : data =>
                        match d0 with
                        | dunit => None
                        | dnat _ => None
                        | dbool true => Some (dcoll (d1 :: nil))
                        | dbool false => Some (dcoll nil)
                        | dstring _ => None
                        | dcoll _ => None
                        | drec _ => None
                        | dleft _ => None
                        | dright _ => None
                        | dbrand _ _ => None
                        | dforeign _ => None
                        end)
                       (olift2
                          (fun d0 d2 : data =>
                           unbdata
                             (fun x y : data =>
                              if data_eq_dec x y then true else false) d0
                             d2)
                          match d1 with
                          | dunit => None
                          | dnat _ => None
                          | dbool _ => None
                          | dstring _ => None
                          | dcoll _ => None
                          | drec r => Some (drec (rproject r sl))
                          | dleft _ => None
                          | dright _ => None
                          | dbrand _ _ => None
                          | dforeign _ => None
                          end (Some d))) incoll))).
    Proof.
      induction incoll; simpl in *; [reflexivity| ].
      unfold group_of_key in *.
      simpl in *.
      destruct a; simpl in *; try congruence.
      rewrite key_is_eq_with_project_eq.
      destruct (data_eq_dec (drec (rproject l sl)) d); simpl.
      - destruct (lift_filter
                    (fun d0 : data =>
                       key_is_eq_r
                         (fun d1 : data =>
                            match d1 with
                            | dunit => None
                            | dnat _ => None
                            | dbool _ => None
                            | dstring _ => None
                            | dcoll _ => None
                            | drec r => Some (drec (rproject r sl))
                            | dleft _ => None
                            | dright _ => None
                            | dbrand _ _ => None
                            | dforeign _ => None
                            end) d0 d) incoll);
        destruct ((rmap
             (fun d1 : data =>
              olift
                (fun d0 : data =>
                 match d0 with
                 | dunit => None
                 | dnat _ => None
                 | dbool true => Some (dcoll (d1 :: nil))
                 | dbool false => Some (dcoll nil)
                 | dstring _ => None
                 | dcoll _ => None
                 | drec _ => None
                 | dleft _ => None
                 | dright _ => None
                 | dbrand _ _ => None
                 | dforeign _ => None
                 end)
                (olift2
                   (fun d0 d2 : data =>
                    unbdata
                      (fun x y : data =>
                       if data_eq_dec x y then true else false) d0 d2)
                   match d1 with
                   | dunit => None
                   | dnat _ => None
                   | dbool _ => None
                   | dstring _ => None
                   | dcoll _ => None
                   | drec r => Some (drec (rproject r sl))
                   | dleft _ => None
                   | dright _ => None
                   | dbrand _ _ => None
                   | dforeign _ => None
                   end (Some d))) incoll)); simpl in *; try congruence.
        case_eq (rflatten l1); intros.
        subst.
        rewrite H in IHincoll; simpl in *.
        inversion IHincoll; subst.
        rewrite (rflatten_cons _ _ l2); try assumption. reflexivity.
        rewrite H in IHincoll; simpl in *; congruence.
        case_eq (rflatten l0); intros; subst; simpl in *; try congruence.
        rewrite H in IHincoll; simpl in *; congruence.
        rewrite H in IHincoll; simpl in *.
        rewrite rflatten_cons_none; [reflexivity|assumption].
      - destruct (lift_filter
                    (fun d0 : data =>
                       key_is_eq_r
                         (fun d1 : data =>
                            match d1 with
                            | dunit => None
                            | dnat _ => None
                            | dbool _ => None
                            | dstring _ => None
                            | dcoll _ => None
                            | drec r => Some (drec (rproject r sl))
                            | dleft _ => None
                            | dright _ => None
                            | dbrand _ _ => None
                            | dforeign _ => None
                            end) d0 d) incoll);
        destruct ((rmap
             (fun d1 : data =>
              olift
                (fun d0 : data =>
                 match d0 with
                 | dunit => None
                 | dnat _ => None
                 | dbool true => Some (dcoll (d1 :: nil))
                 | dbool false => Some (dcoll nil)
                 | dstring _ => None
                 | dcoll _ => None
                 | drec _ => None
                 | dleft _ => None
                 | dright _ => None
                 | dbrand _ _ => None
                 | dforeign _ => None
                 end)
                (olift2
                   (fun d0 d2 : data =>
                    unbdata
                      (fun x y : data =>
                       if data_eq_dec x y then true else false) d0 d2)
                   match d1 with
                   | dunit => None
                   | dnat _ => None
                   | dbool _ => None
                   | dstring _ => None
                   | dcoll _ => None
                   | drec r => Some (drec (rproject r sl))
                   | dleft _ => None
                   | dright _ => None
                   | dbrand _ _ => None
                   | dforeign _ => None
                   end (Some d))) incoll)); simpl in *; try congruence.
        case_eq (rflatten l1); intros.
        subst.
        rewrite H in IHincoll; simpl in *.
        inversion IHincoll; subst.
        rewrite (rflatten_cons _ _ l2); try assumption.
        rewrite H in IHincoll; simpl in *; congruence.
        case_eq (rflatten l0); intros; subst; simpl in *; try congruence.
        rewrite H in IHincoll; simpl in *; congruence.
        rewrite H in IHincoll; simpl in *.
        rewrite rflatten_cons_none; [reflexivity|assumption].
    Qed.

    Lemma group_of_key_destruct_drec_inv g sl d l0 l1 incoll:
      match d with
      | dunit => None
      | dnat _ => None
      | dbool _ => None
      | dstring _ => None
      | dcoll _ => None
      | drec r2 =>
        Some
          (drec
             (insertion_sort_insert rec_field_lt_dec 
                                    (g, dcoll l1) (rec_sort r2)))
      | dleft _ => None
      | dright _ => None
      | dbrand _ _ => None
      | dforeign _ => None
      end = None ->
      olift (to_partitions g)
            (lift (fun t' : list (data * list data) => (d, l1) :: t')
                  (rmap
                     (fun k : data =>
                        olift (fun group : list data => Some (k, group))
                              (group_of_key
                                 (fun d : data =>
                                    match d with
                                    | dunit => None
                                    | dnat _ => None
                      | dbool _ => None
                      | dstring _ => None
                      | dcoll _ => None
                      | drec r => Some (drec (rproject r sl))
                      | dleft _ => None
                      | dright _ => None
                      | dbrand _ _ => None
                      | dforeign _ => None
                                    end) k incoll)) l0)) = None.
    Proof.
      intros.
      case_eq d; intros; subst; simpl in *; try congruence;
      destruct (rmap
          (fun k : data =>
           olift (fun group : list data => Some (k, group))
             (group_of_key
                (fun d : data =>
                 match d with
                 | dunit => None
                 | dnat _ => None
                 | dbool _ => None
                 | dstring _ => None
                 | dcoll _ => None
                 | drec r => Some (drec (rproject r sl))
                 | dleft _ => None
                 | dright _ => None
                 | dbrand _ _ => None
                 | dforeign _ => None
                 end) k incoll)) l0); simpl;
      unfold to_partitions; simpl; try reflexivity.
    Qed.

    Lemma test l0 g sl l1 l2 incoll :
      olift (to_partitions g)
            (lift (fun t' : list (data * list data) => (drec l2, l1) :: t')
                  (rmap
                     (fun k : data =>
                        olift (fun group : list data => Some (k, group))
                              (group_of_key
                                 (fun d : data =>
                                    match d with
                                    | dunit => None
                                    | dnat _ => None
                                    | dbool _ => None
                                    | dstring _ => None
                                    | dcoll _ => None
                                    | drec r => Some (drec (rproject r sl))
                                    | dleft _ => None
                                    | dright _ => None
                                    | dbrand _ _ => None
                                    | dforeign _ => None
                                    end) k incoll)) l0))
      =
      lift
        (fun t' : list data =>
           drec
             (insertion_sort_insert rec_field_lt_dec 
                                    (g, dcoll l1) (rec_sort l2)) :: t')
        (rmap
           (fun d1 : data =>
              olift2
                (fun d0 d2 : data =>
                   match d0 with
                   | dunit => None
                   | dnat _ => None
                   | dbool _ => None
                   | dstring _ => None
                   | dcoll _ => None
                   | drec r1 =>
                     match d2 with
                     | dunit => None
                     | dnat _ => None
                     | dbool _ => None
                     | dstring _ => None
                     | dcoll _ => None
                     | drec r2 => Some (drec (rec_sort (r1 ++ r2)))
                     | dleft _ => None
                     | dright _ => None
                     | dbrand _ _ => None
                     | dforeign _ => None
                     end
                   | dleft _ => None
                   | dright _ => None
                   | dbrand _ _ => None
                   | dforeign _ => None
                   end)
                (olift (fun d0 : data => Some (drec ((g, d0) :: nil)))
                       (olift
                          (fun d0 : data =>
                             lift_oncoll
                               (fun l3 : list data => lift dcoll (rflatten l3)) d0)
                          (lift dcoll
                                (rmap
                                   (fun d0 : data =>
                                      olift
                                        (fun d2 : data =>
                                           match d2 with
                                           | dunit => None
                                           | dnat _ => None
                                           | dbool true => Some (dcoll (d0 :: nil))
                                           | dbool false => Some (dcoll nil)
                                           | dstring _ => None
                                           | dcoll _ => None
                                           | drec _ => None
                                           | dleft _ => None
                                           | dright _ => None
                                           | dbrand _ _ => None
                                           | dforeign _ => None
                                           end)
                                        (olift2
                                           (fun d2 d3 : data =>
                                              unbdata
                                                (fun x y : data =>
                                                   if data_eq_dec x y then true else false)
                                                d2 d3)
                                           match d0 with
                                           | dunit => None
                                           | dnat _ => None
                                           | dbool _ => None
                                           | dstring _ => None
                                           | dcoll _ => None
                                           | drec r => Some (drec (rproject r sl))
                                           | dleft _ => None
                                           | dright _ => None
                                           | dbrand _ _ => None
                                           | dforeign _ => None
                                           end (Some d1))) incoll)))) 
                (Some d1)) l0).
    Proof.
      intros.
      induction l0; simpl.
      - unfold to_partitions, group_to_partitions.
        reflexivity.
      - rewrite <- group_of_key_over_table_correct.
        destruct (group_of_key
              (fun d : data =>
               match d with
               | dunit => None
               | dnat _ => None
               | dbool _ => None
               | dstring _ => None
               | dcoll _ => None
               | drec r => Some (drec (rproject r sl))
               | dleft _ => None
               | dright _ => None
               | dbrand _ _ => None
               | dforeign _ => None
               end) a incoll); intros; simpl; try reflexivity.
        case_eq (match a with
                 | dunit => None
                 | dnat _ => None
                 | dbool _ => None
                 | dstring _ => None
                 | dcoll _ => None
                 | drec r2 =>
                   Some
                     (drec
                        (insertion_sort_insert rec_field_lt_dec 
                                               (g, dcoll l) (rec_sort r2)))
                 | dleft _ => None
                 | dright _ => None
                 | dbrand _ _ => None
                 | dforeign _ => None
                 end); intros.
        + simpl in *. 
          destruct (rmap
             (fun k : data =>
              olift (fun group : list data => Some (k, group))
                (group_of_key
                   (fun d0 : data =>
                    match d0 with
                    | dunit => None
                    | dnat _ => None
                    | dbool _ => None
                    | dstring _ => None
                    | dcoll _ => None
                    | drec r => Some (drec (rproject r sl))
                    | dleft _ => None
                    | dright _ => None
                    | dbrand _ _ => None
                    | dforeign _ => None
                    end) k incoll)) l0); simpl in *;
          destruct (rmap
              (fun d1 : data =>
               olift2
                 (fun d0 d2 : data =>
                  match d0 with
                  | dunit => None
                  | dnat _ => None
                  | dbool _ => None
                  | dstring _ => None
                  | dcoll _ => None
                  | drec r1 =>
                      match d2 with
                      | dunit => None
                      | dnat _ => None
                      | dbool _ => None
                      | dstring _ => None
                      | dcoll _ => None
                      | drec r2 => Some (drec (rec_sort (r1 ++ r2)))
                      | dleft _ => None
                      | dright _ => None
                      | dbrand _ _ => None
                      | dforeign _ => None
                      end
                  | dleft _ => None
                  | dright _ => None
                  | dbrand _ _ => None
                  | dforeign _ => None
                  end)
                 (olift (fun d0 : data => Some (drec ((g, d0) :: nil)))
                    (olift
                       (fun d0 : data =>
                        lift_oncoll
                          (fun l3 : list data => lift dcoll (rflatten l3))
                          d0)
                       (lift dcoll
                          (rmap
                             (fun d0 : data =>
                              olift
                                (fun d2 : data =>
                                 match d2 with
                                 | dunit => None
                                 | dnat _ => None
                                 | dbool true => Some (dcoll (d0 :: nil))
                                 | dbool false => Some (dcoll nil)
                                 | dstring _ => None
                                 | dcoll _ => None
                                 | drec _ => None
                                 | dleft _ => None
                                 | dright _ => None
                                 | dbrand _ _ => None
                                 | dforeign _ => None
                                 end)
                                (olift2
                                   (fun d2 d3 : data =>
                                    unbdata
                                      (fun x y : data =>
                                       if data_eq_dec x y
                                       then true
                                       else false) d2 d3)
                                   match d0 with
                                   | dunit => None
                                   | dnat _ => None
                                   | dbool _ => None
                                   | dstring _ => None
                                   | dcoll _ => None
                                   | drec r => Some (drec (rproject r sl))
                                   | dleft _ => None
                                   | dright _ => None
                                   | dbrand _ _ => None
                                   | dforeign _ => None
                                   end (Some d1))) incoll)))) 
                 (Some d1)) l0); simpl in *; try reflexivity; try congruence;
          unfold to_partitions in *;
          unfold group_to_partitions in *; simpl in *;
          rewrite H in *; simpl;
          destruct (lift_map
        (fun group : data * list data =>
         match fst group with
         | dunit => None
         | dnat _ => None
         | dbool _ => None
         | dstring _ => None
         | dcoll _ => None
         | drec keys =>
             Some
               (drec
                  (insertion_sort_insert rec_field_lt_dec
                     (g, dcoll (snd group)) (rec_sort keys)))
         | dleft _ => None
         | dright _ => None
         | dbrand _ _ => None
         | dforeign _ => None
         end) l3); try congruence.
        + generalize (group_of_key_destruct_drec_inv g sl a l0 l incoll H); intros.
          auto.
          destruct (rmap
               (fun k : data =>
                olift (fun group : list data => Some (k, group))
                  (group_of_key
                     (fun d : data =>
                      match d with
                      | dunit => None
                      | dnat _ => None
                      | dbool _ => None
                      | dstring _ => None
                      | dcoll _ => None
                      | drec r => Some (drec (rproject r sl))
                      | dleft _ => None
                      | dright _ => None
                      | dbrand _ _ => None
                      | dforeign _ => None
                      end) k incoll)) l0); simpl in *.
          unfold to_partitions in *.
          simpl in *.
          destruct (group_to_partitions g (a, l)); try congruence.
          destruct (lift_map (group_to_partitions g) l3); try congruence.
          reflexivity.
    Qed.

    Lemma group_by_table_correct
          (g:string) (sl:list string)
          (incoll outcoll:list data):
      group_by_nested_eval_table g sl incoll = Some outcoll -> 
      match
        olift (fun d1 : data => rondcoll bdistinct d1)
              (lift dcoll
                    (rmap
                       (fun d1 : data =>
                          match d1 with
                          | dunit => None
                          | dnat _ => None
                          | dbool _ => None
                          | dstring _ => None
                          | dcoll _ => None
                          | drec r => Some (drec (rproject r sl))
                          | dleft _ => None
                          | dright _ => None
                          | dbrand _ _ => None
                          | dforeign _ => None
                          end) incoll))
      with
      | Some dunit => None
      | Some (dnat _) => None
      | Some (dbool _) => None
      | Some (dstring _) => None
      | Some (dcoll c1) =>
        lift dcoll
             (rmap
                (fun d1 : data =>
                   olift2
                     (fun d0 d2 : data =>
                        match d0 with
                        | dunit => None
                        | dnat _ => None
                        | dbool _ => None
                        | dstring _ => None
                        | dcoll _ => None
                        | drec r1 =>
                          match d2 with
                          | dunit => None
                          | dnat _ => None
                          | dbool _ => None
                          | dstring _ => None
                          | dcoll _ => None
                          | drec r2 => Some (drec (rec_sort (r1 ++ r2)))
                          | dleft _ => None
                          | dright _ => None
                          | dbrand _ _ => None
                          | dforeign _ => None
                          end
                        | dleft _ => None
                        | dright _ => None
                        | dbrand _ _ => None
                        | dforeign _ => None
                        end)
                     (olift (fun d0 : data => Some (drec ((g, d0) :: nil)))
                            (olift
                               (fun d0 : data =>
                                  lift_oncoll
                                    (fun l : list data => lift dcoll (rflatten l)) d0)
                               (lift dcoll
                                     (rmap
                                        (fun d0 : data =>
                                           olift
                                             (fun d2 : data =>
                                                match d2 with
                                                | dunit => None
                                                | dnat _ => None
                                                | dbool true => Some (dcoll (d0 :: nil))
                                                | dbool false => Some (dcoll nil)
                                                | dstring _ => None
                                                | dcoll _ => None
                                                | drec _ => None
                                                | dleft _ => None
                                                | dright _ => None
                                                | dbrand _ _ => None
                                                | dforeign _ => None
                                                end)
                                             (olift2
                                                (fun d2 d3 : data =>
                                                   unbdata
                                                     (fun x y : data =>
                                                        if data_eq_dec x y
                                                        then true
                                                        else false) d2 d3)
                                                match d0 with
                                                | dunit => None
                                                | dnat _ => None
                                                | dbool _ => None
                                                | dstring _ => None
                                                | dcoll _ => None
                                                | drec r => Some (drec (rproject r sl))
                                                | dleft _ => None
                                                | dright _ => None
                                                | dbrand _ _ => None
                                                | dforeign _ => None
                                                end (Some d1))) incoll)))) 
                     (Some d1)) c1)
      | Some (drec _) => None
      | Some (dleft _) => None
      | Some (dright _) => None
      | Some (dbrand _ _) => None
      | Some (dforeign _) => None
      | None => None
      end = Some (dcoll outcoll).
    Proof.
      intros.
      unfold group_by_nested_eval_table in H.
      unfold group_by_nested_eval_keys_partition in H.
      unfold group_by_nested_eval in H.
      destruct ((rmap
                  (fun d : data =>
                   match d with
                   | dunit => None
                   | dnat _ => None
                   | dbool _ => None
                   | dstring _ => None
                   | dcoll _ => None
                   | drec r => Some (drec (rproject r sl))
                   | dleft _ => None
                   | dright _ => None
                   | dbrand _ _ => None
                   | dforeign _ => None
                   end) incoll)); simpl in *; try congruence.
      destruct (bdistinct l); simpl in *;
      [unfold to_partitions in H; simpl in H; inversion H; auto| ].
      generalize (group_of_key_over_table_correct sl d incoll); intros Htest.
      case_eq (group_of_key
                (fun d : data =>
                 match d with
                 | dunit => None
                 | dnat _ => None
                 | dbool _ => None
                 | dstring _ => None
                 | dcoll _ => None
                 | drec r => Some (drec (rproject r sl))
                 | dleft _ => None
                 | dright _ => None
                 | dbrand _ _ => None
                 | dforeign _ => None
                 end) d incoll); intros;
      rewrite H0 in *; simpl in *; try congruence.
      rewrite <- Htest. 
      simpl.
      case_eq (match d with
      | dunit => None
      | dnat _ => None
      | dbool _ => None
      | dstring _ => None
      | dcoll _ => None
      | drec r2 =>
          Some
            (drec
               (insertion_sort_insert rec_field_lt_dec 
                  (g, dcoll l1) (rec_sort r2)))
      | dleft _ => None
      | dright _ => None
      | dbrand _ _ => None
      | dforeign _ => None
               end); intros.
      - destruct d; simpl in *; try congruence.
        inversion H1; clear H1; subst.
        clear Htest H0.
        rewrite <- (test l0 g sl l1 l2 incoll).
        unfold lift.
        destruct (rmap
              (fun k : data =>
               olift (fun group : list data => Some (k, group))
                 (group_of_key
                    (fun d : data =>
                     match d with
                     | dunit => None
                     | dnat _ => None
                     | dbool _ => None
                     | dstring _ => None
                     | dcoll _ => None
                     | drec r => Some (drec (rproject r sl))
                     | dleft _ => None
                     | dright _ => None
                     | dbrand _ _ => None
                     | dforeign _ => None
                     end) k incoll)) l0); simpl in *.
        rewrite H; reflexivity.
        congruence.
      - generalize (group_of_key_destruct_drec_inv g sl d l0 l1 incoll H1); intros.
        rewrite H2 in H; congruence.
    Qed.
    
  End tableform.
  
  Section normalized.
    Require Import BrandRelation.
    Require Import RDataNorm.
    Context (h:brand_relation_t).

    Lemma bdistinct_normalized l :
      Forall (data_normalized h) l ->
      Forall (data_normalized h) (bdistinct l).
    Proof.
      intros dn.
      rewrite bdistinct_sublist; trivial.
    Qed.

    Lemma rmap_rproject_normalized l l0 o :
      Forall (data_normalized h) l0 ->
      (rmap
         (fun d : data =>
            match d with
            | dunit => None
            | dnat _ => None
            | dbool _ => None
            | dstring _ => None
            | dcoll _ => None
            | drec r => Some (drec (rproject r l))
            | dleft _ => None
            | dright _ => None
            | dbrand _ _ => None
            | dforeign _ => None
            end) l0) = Some o ->
      Forall (data_normalized h) o.
    Proof.
      intros.
      eapply rmap_Forall; eauto; intros.
      simpl in *.
      match_destr_in H1.
      invcs H1.
      invcs H2.
      constructor.
      - rewrite sublist_rproject; trivial.
      - eapply is_list_sorted_sublist; try apply H4.
        apply sublist_domain.
        apply sublist_rproject; trivial.
    Qed.

    Lemma group_of_key_normalized a l l1 l2 :
      Forall (data_normalized h) l1 ->
      group_of_key
           (fun d : data =>
            match d with
            | dunit => None
            | dnat _ => None
            | dbool _ => None
            | dstring _ => None
            | dcoll _ => None
            | drec r => Some (drec (rproject r l))
            | dleft _ => None
            | dright _ => None
            | dbrand _ _ => None
            | dforeign _ => None
            end) a l1 = Some l2 ->
      Forall (data_normalized h) l2.
    Proof.
      intros dn eqq.
      unfold group_of_key.
      eapply lift_filter_Forall; eauto.
    Qed.      

    Lemma group_by_nested_eval_normalized l0 l o :
      Forall (data_normalized h) l0 ->
      (group_by_nested_eval
         (fun d : data =>
            match d with
            | dunit => None
            | dnat _ => None
            | dbool _ => None
            | dstring _ => None
            | dcoll _ => None
            | drec r => Some (drec (rproject r l))
            | dleft _ => None
            | dright _ => None
            | dbrand _ _ => None
            | dforeign _ => None
            end) l0) = Some o ->
      Forall (fun dd => data_normalized h (fst dd)
                        /\ Forall (data_normalized h) (snd dd)) o.
    Proof.
      unfold group_by_nested_eval.
      intros dn eqq.
      unfold olift in eqq.
      match_case_in eqq; [intros ? eqq2 | intros eqq2]
      ; rewrite eqq2 in eqq; try discriminate.
      apply some_lift in eqq2
      ; destruct eqq2 as [d1 eqq2 d2].
      assert (dn1:Forall (data_normalized h) l1).
      { subst.
        apply bdistinct_Forall.
        eapply rmap_rproject_normalized; eauto.
      } 
      clear d1 d2 eqq2.
      revert dn1 o eqq.
      induction l1; simpl; intros dn1 o eqq.
      - invcs eqq; constructor.
      - invcs dn1.
        match_case_in eqq; [intros ? eqq2 | intros eqq2]
      ; rewrite eqq2 in eqq; try discriminate.
      apply some_lift in eqq
      ; destruct eqq as [d1 eqq ?]; subst.
      specialize(IHl1 H2 _ eqq); clear eqq.
      constructor; trivial.
      match_case_in eqq2; [intros ? eqq3 | intros eqq3]
      ; rewrite eqq3 in eqq2; try discriminate.
      invcs eqq2.
      simpl.
      split; trivial.
      eapply group_of_key_normalized; try eapply eqq3.
      trivial.
    Qed.
    
    Lemma group_to_partitions_normalized s a d : 
      data_normalized h (fst a) ->
      Forall (data_normalized h) (snd a) ->
      group_to_partitions s a = Some d ->
      data_normalized h d.
    Proof.
      unfold group_to_partitions.
      intros dn1 dn2 eqq.
      destruct a as [d1 dl1]; unfold fst in *.
      destruct d1; try discriminate.
      assert (deq:d = drec (rec_sort ((s, dcoll (snd (drec l, dl1))) :: l)))
        by (invcs eqq; trivial).
      clear eqq.
      subst d.
      apply dnrec_sort.
      invcs dn1.
      constructor; simpl in *; trivial.
      constructor; trivial.
    Qed.

    Lemma group_by_nested_eval_keys_partition_normalized l0 s l o :
      data_normalized h (dcoll l0) ->
      lift dcoll
           (group_by_nested_eval_keys_partition
              s
              (fun d : data =>
                 match d with
                 | dunit => None
                 | dnat _ => None
                 | dbool _ => None
                 | dstring _ => None
                 | dcoll _ => None
                 | drec r => Some (drec (rproject r l))
                 | dleft _ => None
                 | dright _ => None
                 | dbrand _ _ => None
                 | dforeign _ => None
                 end) l0) = Some o
      -> data_normalized h o.
    Proof.
      unfold group_by_nested_eval_keys_partition, to_partitions.
      intros dn eqq.
      apply some_lift in eqq.
      destruct eqq as [d eqq ?]; subst.
      unfold olift in eqq.
      match_case_in eqq; [intros ? eqq2 | intros eqq2]
      ; rewrite eqq2 in eqq; try discriminate.
      invcs dn.
      generalize (group_by_nested_eval_normalized _ _ _ H0 eqq2); intros dn2.
      clear l0 eqq2 H0.
      revert dn2 d eqq.
      induction l1; intros dn2 d eqq.
      - invcs eqq.
        repeat constructor.
      - invcs dn2.
        specialize (IHl1 H2).
        simpl in eqq.
      match_case_in eqq; [intros ? eqq2 | intros eqq2]
      ; rewrite eqq2 in eqq; try discriminate.
      match_case_in eqq; [intros ? eqq3 | intros eqq3]
      ; rewrite eqq3 in eqq; try discriminate.
      invcs eqq.
      specialize (IHl1 _ eqq3).
      apply data_normalized_dcoll; split; trivial.
      destruct H1.
      eapply group_to_partitions_normalized; eauto.
    Qed.

  End normalized.

End RGroupBy.
  

(*
*** Local Variables: ***
*** coq-load-path: (("../../../coq" "Qcert")) ***
*** End: ***
*)
