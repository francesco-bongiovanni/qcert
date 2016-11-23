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

(*******************************
 * Algebra contexts *
 *******************************)

Section RAlgEnvContext.

  Require Import Equivalence.
  Require Import Morphisms.
  Require Import Setoid.
  Require Import EquivDec.
  Require Import Program.

  Require Import List Permutation.
  Require Import String.
  Require Import NPeano.
  Require Import Arith Bool.

  Require Import Utils BasicRuntime.
  Require Import RAlgEnv RAlgEnvEq.
  Require Import RBindingsNat.

  Local Open Scope algenv_scope.

  Context {fruntime:foreign_runtime}.

  Inductive algenv_ctxt : Set :=
  | CNHole : nat -> algenv_ctxt
  | CNPlug : algenv -> algenv_ctxt
  | CANBinop : binOp -> algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANUnop : unaryOp -> algenv_ctxt -> algenv_ctxt
  | CANMap : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANMapConcat : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANProduct : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANSelect : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANDefault : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANEither : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANEitherConcat : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANApp : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANAppEnv : algenv_ctxt -> algenv_ctxt -> algenv_ctxt
  | CANMapEnv : algenv_ctxt -> algenv_ctxt
  .

  Definition CANID : algenv_ctxt
    := CNPlug ANID.

    Definition CANEnv : algenv_ctxt
    := CNPlug ANEnv.

    Definition CANGetConstant s : algenv_ctxt
    := CNPlug (ANGetConstant s).

  Definition CANConst : data -> algenv_ctxt
    := fun d => CNPlug (ANConst d).

  Fixpoint aec_holes (c:algenv_ctxt) : list nat :=
    match c with
      | CNHole x => x::nil
      | CNPlug a => nil
      | CANBinop b c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANUnop u c' => aec_holes c'
      | CANMap c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANMapConcat c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANProduct c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANSelect c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANDefault c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANEither c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANEitherConcat c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANApp c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANAppEnv c1 c2 => aec_holes c1 ++ aec_holes c2
      | CANMapEnv c1 => aec_holes c1
    end.

  Fixpoint aec_simplify (c:algenv_ctxt) : algenv_ctxt :=
    match c with
      | CNHole x => CNHole x
      | CNPlug a => CNPlug a
      | CANBinop b c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANBinop b a1 a2)
          | c1', c2' => CANBinop b c1' c2'
        end
      | CANUnop u c =>
        match aec_simplify c with
          | CNPlug a => CNPlug (ANUnop u a)
          | c' => CANUnop u c'
        end
      | CANMap c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANMap a1 a2)
          | c1', c2' => CANMap c1' c2'
        end
      | CANMapConcat c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANMapConcat a1 a2)
          | c1', c2' => CANMapConcat c1' c2'
        end
      | CANProduct c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANProduct a1 a2)
          | c1', c2' => CANProduct c1' c2'
        end
      | CANSelect c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANSelect a1 a2)
          | c1', c2' => CANSelect c1' c2'
        end
      | CANDefault c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANDefault a1 a2)
          | c1', c2' => CANDefault c1' c2'
        end
      | CANEither c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANEither a1 a2)
          | c1', c2' => CANEither c1' c2'
        end
      | CANEitherConcat c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANEitherConcat a1 a2)
          | c1', c2' => CANEitherConcat c1' c2'
        end
      | CANApp c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANApp a1 a2)
          | c1', c2' => CANApp c1' c2'
        end
      | CANAppEnv c1 c2 =>
        match aec_simplify c1, aec_simplify c2 with
          | (CNPlug a1), (CNPlug a2) => CNPlug (ANAppEnv a1 a2)
          | c1', c2' => CANAppEnv c1' c2'
        end
      | CANMapEnv c1 =>
        match aec_simplify c1 with
          | (CNPlug a1) => CNPlug (ANMapEnv a1)
          | c1' => CANMapEnv c1'
        end
    end.

  Lemma aec_simplify_holes_preserved c :
    aec_holes (aec_simplify c) = aec_holes c.
  Proof.
    induction c; simpl; trivial;
    try solve [destruct (aec_simplify c1); destruct (aec_simplify c2);
      unfold aec_holes in *; fold aec_holes in *;
      repeat rewrite <- IHc1; repeat rewrite <- IHc2; simpl; trivial];
    try solve [destruct (aec_simplify c);
      unfold aec_holes in *; fold aec_holes in *;
      repeat rewrite <- IHc; simpl; trivial].
  Qed.

  Definition aec_algenv_of_ctxt c
    := match (aec_simplify c) with
         | CNPlug a => Some a
         | _ => None
       end.

  Lemma aec_simplify_nholes c :
    aec_holes c = nil -> {a | aec_simplify c = CNPlug a}.
  Proof.
    induction c; simpl; [discriminate | eauto 2 | ..];
    try solve [intros s0; apply app_eq_nil in s0;
      destruct s0 as [s10 s20];
      destruct (IHc1 s10) as [a1 e1];
        destruct (IHc2 s20) as [a2 e2];
        rewrite e1, e2; eauto 2];
    try solve [intros s0; destruct (IHc s0) as [a e];
    rewrite e; eauto 2].
  Defined.

  Lemma aec_algenv_of_ctxt_nholes c :
    aec_holes c = nil -> {a | aec_algenv_of_ctxt c = Some a}.
  Proof.
    intros ac0.
    destruct (aec_simplify_nholes _ ac0).
    unfold aec_algenv_of_ctxt.
    rewrite e.
    eauto.
  Qed.

  Lemma aec_simplify_idempotent c :
    aec_simplify (aec_simplify c) = aec_simplify c.
  Proof.
    induction c; simpl; trivial;
    try solve [destruct (aec_simplify c); simpl in *; trivial;
               match_destr; try congruence
              | destruct (aec_simplify c1); simpl;
                 try rewrite IHc2; trivial;
                 destruct (aec_simplify c2); simpl in *; trivial;
                 match_destr; try congruence].
  Qed.

  Fixpoint aec_subst (c:algenv_ctxt) (x:nat) (p:algenv) : algenv_ctxt :=
    match c with
      | CNHole x'
        => if x == x' then CNPlug p else CNHole x'
      | CNPlug a
        => CNPlug a
      | CANBinop b c1 c2
        => CANBinop b (aec_subst c1 x p) (aec_subst c2 x p)
      | CANUnop u c
        => CANUnop u (aec_subst c x p)
      | CANMap c1 c2
        => CANMap (aec_subst c1 x p) (aec_subst c2 x p)
      | CANMapConcat c1 c2
        => CANMapConcat (aec_subst c1 x p) (aec_subst c2 x p)
      | CANProduct c1 c2
        => CANProduct (aec_subst c1 x p) (aec_subst c2 x p)
      | CANSelect c1 c2
        => CANSelect (aec_subst c1 x p) (aec_subst c2 x p)
      | CANDefault c1 c2
        => CANDefault (aec_subst c1 x p) (aec_subst c2 x p)
      | CANEither c1 c2
        => CANEither (aec_subst c1 x p) (aec_subst c2 x p)
      | CANEitherConcat c1 c2
        => CANEitherConcat (aec_subst c1 x p) (aec_subst c2 x p)
      | CANApp c1 c2
        => CANApp (aec_subst c1 x p) (aec_subst c2 x p)
      | CANAppEnv c1 c2
        => CANAppEnv (aec_subst c1 x p) (aec_subst c2 x p)
      | CANMapEnv c1
        => CANMapEnv (aec_subst c1 x p)
    end.

  Definition aec_substp (c:algenv_ctxt) xp
    := let '(x, p) := xp in aec_subst c x p.
    
  Definition aec_substs c ps :=
    fold_left aec_substp ps c.

  
   Lemma aec_substs_app c ps1 ps2 :
     aec_substs c (ps1 ++ ps2) =
     aec_substs (aec_substs c ps1) ps2.
   Proof.
     unfold aec_substs.
     apply fold_left_app.
   Qed.

  Lemma aec_subst_holes_nin  c x p :
    ~ In x (aec_holes c) -> aec_subst c x p = c.
  Proof.
    induction c; simpl; intros; 
    [match_destr; intuition | trivial | .. ];
    repeat rewrite in_app_iff in *;
    f_equal; auto.
  Qed.

  Lemma aec_subst_holes_remove c x p :
    aec_holes (aec_subst c x p) = remove_all x (aec_holes c).
  Proof.
    induction c; simpl; intros;
    trivial; try solve[ rewrite remove_all_app; congruence].
    (* CNHole *)
    match_destr; match_destr; simpl; try rewrite app_nil_r; congruence.
  Qed.

    Lemma aec_substp_holes_remove c xp :
      aec_holes (aec_substp c xp) = remove_all (fst xp) (aec_holes c).
  Proof.
    destruct xp; simpl.
    apply aec_subst_holes_remove.
  Qed.

 Lemma aec_substs_holes_remove c ps :
    aec_holes (aec_substs c ps) =
    fold_left (fun h xy => remove_all (fst xy) h) ps (aec_holes c).
  Proof.
    revert c.
    unfold aec_substs.
    induction ps; simpl; trivial; intros.
    rewrite IHps, aec_substp_holes_remove.
    trivial.
  Qed.
  
  Lemma aec_substs_Plug a ps :
    aec_substs (CNPlug a) ps = CNPlug a.
  Proof.
    induction ps; simpl; trivial; intros.
    destruct a0; simpl; auto.
  Qed.
  
  Lemma aec_substs_Binop b c1 c2 ps :
    aec_substs (CANBinop b c1 c2) ps = CANBinop b (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.

  Lemma aec_substs_Unop u c ps :
      aec_substs (CANUnop u c) ps = CANUnop u (aec_substs c ps).
  Proof.
    revert c.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.

  Lemma aec_substs_Map c1 c2 ps :
    aec_substs ( CANMap c1 c2) ps =
    CANMap (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.

  Lemma aec_substs_MapConcat c1 c2 ps :
    aec_substs ( CANMapConcat c1 c2) ps =
    CANMapConcat (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_Product c1 c2 ps :
    aec_substs ( CANProduct c1 c2) ps =
    CANProduct (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_Select c1 c2 ps :
    aec_substs ( CANSelect c1 c2) ps =
    CANSelect (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_Default c1 c2 ps :
    aec_substs ( CANDefault c1 c2) ps =
    CANDefault (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_Either c1 c2 ps :
    aec_substs ( CANEither c1 c2) ps =
    CANEither (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_EitherConcat c1 c2 ps :
    aec_substs ( CANEitherConcat c1 c2) ps =
    CANEitherConcat (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_App c1 c2 ps :
    aec_substs ( CANApp c1 c2) ps =
    CANApp (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_AppEnv c1 c2 ps :
    aec_substs ( CANAppEnv c1 c2) ps =
    CANAppEnv (aec_substs c1 ps) (aec_substs c2 ps).
  Proof.
    revert c1 c2.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.
  
  Lemma aec_substs_MapEnv c1 ps :
    aec_substs ( CANMapEnv c1) ps =
    CANMapEnv (aec_substs c1 ps).
  Proof.
    revert c1.
    induction ps; simpl; trivial; intros.
    destruct a; simpl; auto.
  Qed.

    Hint Rewrite
       aec_substs_Plug
       aec_substs_Binop
       aec_substs_Unop
       aec_substs_Map
       aec_substs_MapConcat
       aec_substs_Product
       aec_substs_Select
       aec_substs_Default
       aec_substs_Either
       aec_substs_EitherConcat
       aec_substs_App
       aec_substs_AppEnv
       aec_substs_MapEnv : aec_substs.
  
  Lemma aec_simplify_holes_binop b c1 c2:
    aec_holes (CANBinop b c1 c2) <> nil ->
    aec_simplify (CANBinop b c1 c2) = CANBinop b (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

  Lemma aec_simplify_holes_unop u c:
    aec_holes (CANUnop u c ) <> nil ->
    aec_simplify (CANUnop u c) = CANUnop u (aec_simplify c).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c); intros pres1;
      simpl; intros.
    match_destr.
    simpl in *; rewrite <- pres1 in H.
    simpl in H; intuition.
  Qed.

  Lemma aec_simplify_holes_map c1 c2:
    aec_holes (CANMap c1 c2) <> nil ->
    aec_simplify (CANMap c1 c2) = CANMap (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_mapconcat c1 c2:
    aec_holes (CANMapConcat c1 c2) <> nil ->
    aec_simplify (CANMapConcat c1 c2) = CANMapConcat (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_product c1 c2:
    aec_holes (CANProduct c1 c2) <> nil ->
    aec_simplify (CANProduct c1 c2) = CANProduct (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_select c1 c2:
    aec_holes (CANSelect c1 c2) <> nil ->
    aec_simplify (CANSelect c1 c2) = CANSelect (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_default c1 c2:
    aec_holes (CANDefault c1 c2) <> nil ->
    aec_simplify (CANDefault c1 c2) = CANDefault (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_either c1 c2:
    aec_holes (CANEither c1 c2) <> nil ->
    aec_simplify (CANEither c1 c2) = CANEither (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_eitherconcat c1 c2:
    aec_holes (CANEitherConcat c1 c2) <> nil ->
    aec_simplify (CANEitherConcat c1 c2) = CANEitherConcat (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_app c1 c2:
    aec_holes (CANApp c1 c2) <> nil ->
    aec_simplify (CANApp c1 c2) = CANApp (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_appenv c1 c2:
    aec_holes (CANAppEnv c1 c2) <> nil ->
    aec_simplify (CANAppEnv c1 c2) = CANAppEnv (aec_simplify c1) (aec_simplify c2).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      generalize (aec_simplify_holes_preserved c2); intros pres2;
      simpl; intros.
    do 2 match_destr.
    simpl in *; rewrite <- pres1, <- pres2 in H.
    simpl in H; intuition.
  Qed.

    Lemma aec_simplify_holes_mapenv c1 :
    aec_holes (CANMapEnv c1) <> nil ->
    aec_simplify (CANMapEnv c1) = CANMapEnv (aec_simplify c1).
  Proof.
    intros.
    simpl in H.
    generalize (aec_simplify_holes_preserved c1); intros pres1;
      simpl; intros.
    match_destr.
    simpl in *; rewrite <- pres1 in H.
    simpl in H; intuition.
  Qed.

   Lemma aec_subst_nholes c x p :
     (aec_holes c) = nil -> aec_subst c x p = c.
   Proof.
     intros. apply aec_subst_holes_nin. rewrite H; simpl.
     intuition.
   Qed.

   Lemma aec_subst_simplify_nholes c x p :
     (aec_holes c) = nil ->
     aec_subst (aec_simplify c) x p = aec_simplify c.
   Proof.
     intros.
     rewrite (aec_subst_nholes (aec_simplify c)); trivial.
     rewrite aec_simplify_holes_preserved; trivial.
   Qed.

  Lemma aec_simplify_subst_simplify1 c x p :
    aec_simplify (aec_subst (aec_simplify c) x p) =
    aec_simplify (aec_subst c x p).
  Proof.
    Ltac destr_solv IHc1 IHc2 const lemma :=
      destruct (is_nil_dec (aec_holes const)) as [h|h];
      [(rewrite (aec_subst_nholes _ _ _ h);
        rewrite (aec_subst_simplify_nholes _ _ _ h);
        rewrite aec_simplify_idempotent;
        trivial)
      | (rewrite lemma; [| eauto];
        simpl;
        rewrite IHc1, IHc2; trivial)].

    induction c.
    - simpl; match_destr.
    - simpl; trivial.
    - destr_solv IHc1 IHc2 (CANBinop b c1 c2) aec_simplify_holes_binop.
    -  destruct (is_nil_dec (aec_holes (CANUnop u c))) as [h|h].
      + rewrite (aec_subst_nholes _ _ _ h).
        rewrite (aec_subst_simplify_nholes _ _ _ h).
        rewrite aec_simplify_idempotent.
        trivial.
      + rewrite aec_simplify_holes_unop; [| eauto].
        simpl.
        rewrite IHc.
        trivial.
    - destr_solv IHc1 IHc2 (CANMap c1 c2) aec_simplify_holes_map.
    - destr_solv IHc1 IHc2 (CANMapConcat c1 c2) aec_simplify_holes_mapconcat.
    - destr_solv IHc1 IHc2 (CANProduct c1 c2) aec_simplify_holes_product.
    - destr_solv IHc1 IHc2 (CANSelect c1 c2) aec_simplify_holes_select.
    - destr_solv IHc1 IHc2 (CANDefault c1 c2) aec_simplify_holes_default.
    - destr_solv IHc1 IHc2 (CANEither c1 c2) aec_simplify_holes_either.
    - destr_solv IHc1 IHc2 (CANEitherConcat c1 c2) aec_simplify_holes_eitherconcat.
    - destr_solv IHc1 IHc2 (CANApp c1 c2) aec_simplify_holes_app.
    - destr_solv IHc1 IHc2 (CANAppEnv c1 c2) aec_simplify_holes_appenv.
    - destruct (is_nil_dec (aec_holes (CANMapEnv c))) as [h|h].
      + rewrite (aec_subst_nholes _ _ _ h).
        rewrite (aec_subst_simplify_nholes _ _ _ h).
        rewrite aec_simplify_idempotent.
        trivial.
      + rewrite aec_simplify_holes_mapenv; [| eauto].
        simpl.
        rewrite IHc.
        trivial.
  Qed.

  Lemma aec_simplify_substs_simplify1 c ps :
    aec_simplify (aec_substs (aec_simplify c) ps) =
    aec_simplify (aec_substs c ps).
  Proof.
    revert c.
    induction ps; simpl.
    - apply aec_simplify_idempotent.
    - destruct a. simpl; intros.
      rewrite <- IHps.
      rewrite aec_simplify_subst_simplify1.
      rewrite IHps; trivial.
  Qed.

    Section equivs.
    Context (base_equiv:algenv->algenv->Prop).

    Definition algenv_ctxt_equiv (c1 c2 : algenv_ctxt)
      := forall (ps:list (nat * algenv)),
           match aec_simplify (aec_substs c1 ps),
                 aec_simplify (aec_substs c2 ps)
           with
             | CNPlug a1, CNPlug a2 => base_equiv a1 a2
             | _, _ => True
           end.

   Definition algenv_ctxt_equiv_strict (c1 c2 : algenv_ctxt)
     := forall (ps:list (nat * algenv)),
          is_list_sorted lt_dec (domain ps) = true ->
          equivlist (domain ps) (aec_holes c1 ++ aec_holes c2) ->
          match aec_simplify (aec_substs c1 ps),
                aec_simplify (aec_substs c2 ps)
          with
            | CNPlug a1, CNPlug a2 => base_equiv a1 a2
            | _, _ => True
          end.

   Global Instance aec_simplify_proper :
     Proper (algenv_ctxt_equiv ==> algenv_ctxt_equiv) aec_simplify.
  Proof.
    unfold Proper, respectful.
    unfold algenv_ctxt_equiv.
    intros.
    repeat rewrite aec_simplify_substs_simplify1.
    specialize (H ps).
    match_destr; match_destr.
  Qed.
  
  Lemma aec_simplify_proper_inv x y:
    algenv_ctxt_equiv (aec_simplify x) (aec_simplify y) -> algenv_ctxt_equiv x y.
 Proof.
    unfold Proper, respectful.
    unfold algenv_ctxt_equiv.
    intros.
    specialize (H ps).
    repeat rewrite aec_simplify_substs_simplify1 in H.
    match_destr; match_destr.
 Qed.

 Instance aec_subst_proper_part1 :
   Proper (algenv_ctxt_equiv ==> eq ==> eq ==> algenv_ctxt_equiv) aec_subst.
  Proof.
    unfold Proper, respectful, algenv_ctxt_equiv.
    intros. subst.
    specialize (H ((y0,y1)::ps)).
    simpl in H.
    match_destr; match_destr.
  Qed.

  Global Instance aec_substs_proper_part1: Proper (algenv_ctxt_equiv ==> eq ==> algenv_ctxt_equiv) aec_substs.
  Proof.
    unfold Proper, respectful, algenv_ctxt_equiv.
    intros. subst.
    repeat rewrite <- aec_substs_app.
    apply H.
  Qed.

  Definition algenv_ctxt_equiv_strict1 (c1 c2 : algenv_ctxt)
     := forall (ps:list (nat * algenv)),
          NoDup (domain ps) ->
          equivlist (domain ps) (aec_holes c1 ++ aec_holes c2) ->
          match aec_simplify (aec_substs c1 ps),
                aec_simplify (aec_substs c2 ps)
          with
            | CNPlug a1, CNPlug a2 => base_equiv a1 a2
            | _, _ => True
          end.

   Lemma aec_subst_swap_neq c x1 x2 y1 y2 :
     x1 <> x2 ->
   aec_subst (aec_subst c x1 y1) x2 y2 =
   aec_subst (aec_subst c x2 y2) x1 y1.
   Proof.
     induction c; simpl;
     [ repeat (match_destr; simpl; try congruence) | trivial | .. ];
     intuition; congruence.
   Qed.
   
   Lemma aec_subst_swap_eq c x1 y1 y2 :
     aec_subst (aec_subst c x1 y1) x1 y2 =
     aec_subst c x1 y1.
   Proof.
      induction c; simpl;
      [ repeat (match_destr; simpl; try congruence) | trivial | .. ];
      intuition; congruence.
   Qed. 
           
   Lemma aec_substs_subst_swap_simpl x c y ps :
     ~ In x (domain ps) ->
      aec_substs (aec_subst c x y) ps
      =
      (aec_subst (aec_substs c ps) x y).
   Proof.
     revert c.
     induction ps; simpl; trivial; intros.
     rewrite <- IHps; trivial.
     + unfold aec_substp.
       destruct a.
       rewrite aec_subst_swap_neq; trivial.
       intuition.
     + intuition.
   Qed.
   
   Lemma aec_substs_perm c ps1 ps2 :
     NoDup (domain ps1) ->
     Permutation ps1 ps2 ->
     (aec_substs c ps1)  =
     (aec_substs c ps2).
   Proof.
     intros nd perm.
     revert c. revert ps1 ps2 perm nd.
     apply (Permutation_ind_bis
              (fun ps1 ps2 =>
                 NoDup (domain ps1) ->
                 forall c : algenv_ctxt,
                   aec_substs c ps1 =
                   aec_substs c ps2 )); intros; simpl.
     - trivial.
     - inversion H1; subst. rewrite H0; trivial.
     - inversion H1; subst.
       inversion H5; subst.
       rewrite H0; trivial. destruct x; destruct y; simpl.
       rewrite aec_subst_swap_neq; trivial.
       simpl in *.
       intuition.
     - rewrite H0, H2; trivial.
       rewrite <- H. trivial.
   Qed. 
       
   (* They don't need to be sorted, as long as there are no duplicates *)
   Lemma algenv_ctxt_equiv_strict_equiv1 (c1 c2 : algenv_ctxt) :
     algenv_ctxt_equiv_strict1 c1 c2 <-> algenv_ctxt_equiv_strict c1 c2.
   Proof.
     unfold algenv_ctxt_equiv_strict, algenv_ctxt_equiv_strict1.
     split; intros.
     - apply H; trivial.
       apply is_list_sorted_NoDup in H0; trivial.
       apply Nat.lt_strorder.
     - specialize (H (rec_sort ps)).
       cut_to H.
       + Hint Resolve rec_sort_perm.
         rewrite aec_substs_perm with (c:=c1) (ps2:=(rec_sort ps)); auto.
         rewrite aec_substs_perm with (c:=c2) (ps2:=(rec_sort ps)); auto.
       + apply (@rec_sort_pf nat ODT_nat).
       + rewrite drec_sort_equiv_domain. trivial.
   Qed.

   (* we don't really need to worry about duplicates either *)
   Definition algenv_ctxt_equiv_strict2 (c1 c2 : algenv_ctxt)
     := forall (ps:list (nat * algenv)),
          equivlist (domain ps) (aec_holes c1 ++ aec_holes c2) ->
          match aec_simplify (aec_substs c1 ps),
                aec_simplify (aec_substs c2 ps)
          with
            | CNPlug a1, CNPlug a2 => base_equiv a1 a2
            | _, _ => True
          end.

   Lemma aec_substs_in_nholes c x ps :
         In x (domain ps) ->
      ~ In x (aec_holes (aec_substs c ps)).
   Proof.
     rewrite aec_substs_holes_remove.
     intros.
     intros inn.
     apply (fold_left_remove_all_nil_in_not_inv inn); trivial.
   Qed. 
    
   Lemma substs_bdistinct_domain_rev c ps :
    (aec_substs c (bdistinct_domain (rev ps)))
    = 
    (aec_substs c ps).
  Proof.
    revert c.
    induction ps using rev_ind; simpl; trivial.
    rewrite rev_app_distr.
    simpl; intros.
    rewrite aec_substs_app.
    simpl.
    match_case; simpl; intros.
    - rewrite IHps.
      rewrite existsb_exists in H.
      destruct H as [? [? eqq]].
      unfold equiv_decb in eqq.
      match_destr_in eqq.
      destruct x; destruct x0; red in e; simpl in *.
      subst.
      apply in_dom in H.
      generalize (equivlist_in (bdistinct_domain_domain_equiv (rev ps)) _ H); intros eqq1.
      rewrite domain_rev in eqq1.
      generalize (Permutation_in _ (symmetry (Permutation_rev (domain ps))) eqq1); intros eqq2.
      rewrite aec_subst_holes_nin; trivial.
      apply aec_substs_in_nholes.
      trivial.
    - rewrite IHps.
      rewrite existsb_not_forallb, negb_false_iff, forallb_forall in H.
      destruct x; simpl.
      rewrite aec_substs_subst_swap_simpl; trivial.
      intros inn.
      apply bdistinct_rev_domain_equivlist in inn.
      apply in_domain_in in inn.
      destruct inn.
      specialize (H _ H0).
      unfold equiv_decb in *. match_destr_in H.
      simpl in *. intuition.
  Qed.
  
   Lemma algenv_ctxt_equiv_strict1_equiv2 (c1 c2 : algenv_ctxt) :
     algenv_ctxt_equiv_strict2 c1 c2 <-> algenv_ctxt_equiv_strict1 c1 c2.
   Proof.
     unfold algenv_ctxt_equiv_strict1, algenv_ctxt_equiv_strict2.
     split; intros H.
     - intros. apply H; trivial.
     - intros.
       specialize (H (bdistinct_domain (rev ps))).
       cut_to H.
       + repeat  rewrite substs_bdistinct_domain_rev in H.
          trivial.
       + apply bdistinct_domain_NoDup.
       + rewrite bdistinct_domain_domain_equiv.
         rewrite <- Permutation_rev.
         trivial.
   Qed.

   (* we don't really need to worry about having extra stuff either *)
   Definition algenv_ctxt_equiv_strict3 (c1 c2 : algenv_ctxt)
     := forall (ps:list (nat * algenv)),
          incl (aec_holes c1 ++ aec_holes c2) (domain ps)  ->
          match aec_simplify (aec_substs c1 ps),
                aec_simplify (aec_substs c2 ps)
          with
            | CNPlug a1, CNPlug a2 => base_equiv a1 a2
            | _, _ => True
          end.
   
   Lemma cut_down_to_substs c ps cut :
     incl (aec_holes c) cut ->
     (aec_substs c ps) = (aec_substs c (cut_down_to ps cut)).
   Proof.
     revert c.
     induction ps; simpl; trivial; intros.
     match_case.
     - simpl; intros. apply IHps; simpl.
       rewrite aec_substp_holes_remove; simpl.
       rewrite remove_all_filter.
       red; intros ? inn.
       apply filter_In in inn. destruct inn as [inn1 ?].
       apply (H _ inn1).
     - destruct a. intros; simpl; rewrite aec_subst_holes_nin; eauto.
       rewrite existsb_not_forallb, negb_false_iff, forallb_forall in H0.
       intros inn; specialize (H _ inn).
       specialize (H0 _ H).
       unfold equiv_decb in *; match_destr_in H0.
       simpl in *.
       congruence.
   Qed.
         
   Lemma algenv_ctxt_equiv_strict2_equiv3 (c1 c2 : algenv_ctxt) :
     algenv_ctxt_equiv_strict3 c1 c2 <-> algenv_ctxt_equiv_strict2 c1 c2.
   Proof.
     unfold algenv_ctxt_equiv_strict2, algenv_ctxt_equiv_strict3.
     split; intros H.
     - intros. apply H; trivial. unfold equivlist, incl in *.
       intros; apply H0; trivial.
     - intros. specialize (H
                             (cut_down_to ps
                                          (aec_holes c1 ++ aec_holes c2))).
       cut_to H.
       + rewrite <- (cut_down_to_substs c1 ps (aec_holes c1 ++ aec_holes c2)) in H.
          rewrite <- (cut_down_to_substs c2 ps (aec_holes c1 ++ aec_holes c2)) in H.
         * trivial.
         * red; intros; rewrite in_app_iff; eauto.
         * red; intros; rewrite in_app_iff; eauto.
       + apply equivlist_incls; split.
         * apply cut_down_to_incl_to.
         * apply incl_domain_cut_down_incl; trivial.
   Qed.

   Lemma algenv_ctxt_equiv_strict3_equiv (c1 c2 : algenv_ctxt) :
     algenv_ctxt_equiv c1 c2 <-> algenv_ctxt_equiv_strict3 c1 c2.
   Proof.
     unfold algenv_ctxt_equiv_strict3, algenv_ctxt_equiv.
     intros.
      split; intros H.
     - intros. apply H; trivial.
     - intros ps.
       destruct (incl_dec (aec_holes c1 ++ aec_holes c2) (domain ps)).
       + apply (H ps); trivial.
       + apply nincl_exists in n. destruct n as [x [inx ninx]].
         rewrite in_app_iff in inx. destruct inx.
         * generalize (aec_substs_holes_remove c1 ps).
           rewrite <- aec_simplify_holes_preserved.
           match_destr; simpl; intros eqq.
           generalize (fold_left_remove_all_nil_in H0 ninx); intros inn.
           rewrite <- eqq in inn.
           inversion inn.
         * generalize (aec_substs_holes_remove c2 ps).
           rewrite <- aec_simplify_holes_preserved.
           match_destr; match_destr; simpl; intros eqq.
           generalize (fold_left_remove_all_nil_in H0 ninx); intros inn.
            rewrite <- eqq in inn.
           inversion inn.
   Qed.

   Theorem algenv_ctxt_equiv_strict_equiv (c1 c2 : algenv_ctxt) :
     algenv_ctxt_equiv c1 c2 <-> algenv_ctxt_equiv_strict c1 c2.
   Proof.
     rewrite algenv_ctxt_equiv_strict3_equiv,
     algenv_ctxt_equiv_strict2_equiv3,
     algenv_ctxt_equiv_strict1_equiv2,
     algenv_ctxt_equiv_strict_equiv1.
     reflexivity.
   Qed.

   Lemma aec_holes_saturated_subst {B} f c ps :
      incl (aec_holes c) (domain ps) ->
      aec_holes
        (aec_substs c
                   (map (fun xy : nat * B => (fst xy, (f (snd xy)))) ps)) = nil.
  Proof.
    intros.
    rewrite aec_substs_holes_remove, fold_left_map.
    simpl.
    replace (fold_left
     (fun (a : list nat) (b : nat * B) => remove_all (fst b) a)
     ps (aec_holes c) ) with
    ( fold_left
     (fun (a : list nat) (b : nat) =>  filter (nequiv_decb b) a)
     (map fst ps) (aec_holes c)).
    - case_eq (fold_left (fun (a : list nat) (b : nat) =>
                            filter (nequiv_decb b) a)
                         (map fst ps) (aec_holes c)); trivial.
      intros.
      assert (inn:In n (n::l)) by (simpl; intuition).
      rewrite <- H0 in inn.
      apply fold_left_remove_all_In in inn.
      destruct inn as [inn1 inn2].
      specialize (H _ inn1).
      elim (inn2 H).
    - rewrite fold_left_map.
      apply fold_left_ext. intros.
      rewrite remove_all_filter. trivial.
  Qed.

  Global Instance algenv_ctxt_equiv_refl {refl:Reflexive base_equiv}: Reflexive algenv_ctxt_equiv.
  Proof.
    unfold algenv_ctxt_equiv.
    red; intros.
    - match_destr; reflexivity.
  Qed.   

  Global Instance algenv_ctxt_equiv_sym {sym:Symmetric base_equiv}: Symmetric algenv_ctxt_equiv.
  Proof.
    unfold algenv_ctxt_equiv.
    red; intros.
    - specialize (H ps). match_destr; match_destr. symmetry. trivial.
  Qed.

  Global Instance algenv_ctxt_equiv_trans {trans:Transitive base_equiv}: Transitive algenv_ctxt_equiv.
  Proof.
    unfold algenv_ctxt_equiv.
    red; intros.
    - specialize (H (ps ++ (map (fun x => (x, ANID)) (aec_holes y)))).
      specialize (H0 (ps ++ (map (fun x => (x, ANID)) (aec_holes y)))).
      repeat rewrite map_app in H, H0.
      rewrite (aec_substs_app x) in H.
      rewrite (aec_substs_app z) in H0.
      rewrite <- (aec_simplify_substs_simplify1
                    (aec_substs x ps)
                (map (fun x : nat => (x, ID)) (aec_holes y))) in H.
      rewrite <- (aec_simplify_substs_simplify1
                    (aec_substs z ps)
                    (map (fun x : nat => (x, ID)) (aec_holes y))) in H0.
      match_destr.
      match_destr.
      autorewrite with aec_substs in *; simpl in *.
      assert (nholes:aec_holes
               (aec_substs y
              (ps ++
                 (map (fun x : nat => (x, ID)) (aec_holes y)))) = nil).
      + simpl.
        rewrite aec_substs_holes_remove.
        rewrite fold_left_app.
        rewrite fold_left_map.
        simpl.
        case_eq (fold_left (fun (a1 : list nat) (b : nat) => remove_all b a1)
     (aec_holes y)
     (fold_left
        (fun (a1 : list nat) (b : nat * algenv) =>
           remove_all (fst b) a1) ps (aec_holes y))); trivial.
        intros n rl fle.
        assert (inn:In n (n::rl)) by (simpl; intuition).
        rewrite <- fle in inn.
        generalize (fold_left_remove_all_nil_in_inv' inn); intros inn2.
        generalize (fold_left_remove_all_nil_in_not_inv' inn); intros nin2.
        apply fold_left_remove_all_nil_in_inv in inn2.
        intuition.
      + destruct (aec_simplify_nholes _ nholes) as [? eqq].
        rewrite eqq in H, H0.
        transitivity x0; trivial.
  Qed.

  Global Instance algenv_ctxt_equiv_equivalence {equiv:Equivalence base_equiv}: Equivalence algenv_ctxt_equiv.
  Proof.
    constructor; red; intros.
    - reflexivity.
    - symmetry; trivial.
    - etransitivity; eauto.
  Qed.

  Global Instance algenv_ctxt_equiv_preorder {pre:PreOrder base_equiv} : PreOrder algenv_ctxt_equiv.
  Proof.
    constructor; red; intros.
    - reflexivity.
    - etransitivity; eauto.
  Qed.

  Global Instance algenv_ctxt_equiv_strict_refl {refl:Reflexive base_equiv}: Reflexive algenv_ctxt_equiv_strict.
  Proof.
    red; intros.
    repeat rewrite <- algenv_ctxt_equiv_strict_equiv in *.
    reflexivity.
  Qed.   

  Global Instance algenv_ctxt_equiv_strict_sym {sym:Symmetric base_equiv}: Symmetric algenv_ctxt_equiv_strict.
  Proof.
    red; intros.
    repeat rewrite <- algenv_ctxt_equiv_strict_equiv in *.
    symmetry; trivial.
  Qed.   

  Global Instance algenv_ctxt_equiv_strict_trans {trans:Transitive base_equiv}: Transitive algenv_ctxt_equiv_strict.
  Proof.
    red; intros.
    repeat rewrite <- algenv_ctxt_equiv_strict_equiv in *.
    etransitivity; eauto.
  Qed.
  
  Global Instance algenv_ctxt_equiv_strict_equivalence {equiv:Equivalence base_equiv}: Equivalence algenv_ctxt_equiv_strict.
  Proof.
    constructor; red; intros.
    - reflexivity.
    - symmetry; trivial.
    - etransitivity; eauto.
  Qed.

  Global Instance algenv_ctxt_equiv_strict_preorder {pre:PreOrder base_equiv} : PreOrder algenv_ctxt_equiv_strict.
  Proof.
    constructor; red; intros.
    - reflexivity.
    - etransitivity; eauto.
  Qed.

  Global Instance CNPlug_proper :
    Proper (base_equiv ==> algenv_ctxt_equiv) CNPlug.
  Proof.
    unfold Proper, respectful.
    unfold algenv_ctxt_equiv.
    intros. autorewrite with aec_substs.
    simpl; trivial.
  Qed.

  Global Instance CNPlug_proper_strict :
    Proper (base_equiv ==> algenv_ctxt_equiv_strict) CNPlug.
  Proof.
    unfold Proper, respectful.
    unfold algenv_ctxt_equiv_strict.
    intros. autorewrite with aec_substs.
    simpl; trivial.
  Qed.

  End equivs.
  
   End RAlgEnvContext.

(* TODO: show that the constructors of context are all proper with respect to context equivalence *)

Delimit Scope algenv_ctxt_scope with algenv_ctxt.

Notation "'ID'" := (CANID)  (at level 50) : algenv_ctxt_scope.
Notation "'ENV'" := (CANEnv)  (at level 50) : algenv_ctxt_scope.

Notation "‵‵ c" := (CANConst (dconst c))  (at level 0) : algenv_ctxt_scope.                           (* ‵ = \baeckprime *)
Notation "‵ c" := (CANConst c)  (at level 0) : algenv_ctxt_scope.                                     (* ‵ = \baeckprime *)
Notation "‵{||}" := (CANConst (dcoll nil))  (at level 0) : algenv_ctxt_scope.                         (* ‵ = \baeckprime *)
Notation "‵[||]" := (CANConst (drec nil)) (at level 50) : algenv_ctxt_scope.                          (* ‵ = \baeckprime *)

Notation "r1 ∧ r2" := (CANBinop AAnd r1 r2) (right associativity, at level 65): algenv_ctxt_scope.    (* ∧ = \wedge *)
Notation "r1 ∨ r2" := (CANBinop AOr r1 r2) (right associativity, at level 70): algenv_ctxt_scope.     (* ∨ = \vee *)
Notation "r1 ≐ r2" := (CANBinop AEq r1 r2) (right associativity, at level 70): algenv_ctxt_scope.     (* ≐ = \doteq *)
Notation "r1 ≤ r2" := (CANBinop ALt r1 r2) (no associativity, at level 70): algenv_ctxt_scope.     (* ≤ = \leq *)
Notation "r1 ⋃ r2" := (CANBinop AUnion r1 r2) (right associativity, at level 70): algenv_ctxt_scope.  (* ⋃ = \bigcup *)
Notation "r1 − r2" := (CANBinop AMinus r1 r2) (right associativity, at level 70): algenv_ctxt_scope.  (* − = \minus *)
Notation "r1 ♯min r2" := (CANBinop AMin r1 r2) (right associativity, at level 70): algenv_ctxt_scope. (* ♯ = \sharp *)
Notation "r1 ♯max r2" := (CANBinop AMax r1 r2) (right associativity, at level 70): algenv_ctxt_scope. (* ♯ = \sharp *)
Notation "p ⊕ r"   := ((CANBinop AConcat) p r) (at level 70) : algenv_ctxt_scope.                     (* ⊕ = \oplus *)
Notation "p ⊗ r"   := ((CANBinop AMergeConcat) p r) (at level 70) : algenv_ctxt_scope.                (* ⊗ = \otimes *)

Notation "¬( r1 )" := (CANUnop ANeg r1) (right associativity, at level 70): algenv_ctxt_scope.        (* ¬ = \neg *)
Notation "ε( r1 )" := (CANUnop ADistinct r1) (right associativity, at level 70): algenv_ctxt_scope.   (* ε = \epsilon *)
Notation "♯count( r1 )" := (CANUnop ACount r1) (right associativity, at level 70): algenv_ctxt_scope. (* ♯ = \sharp *)
Notation "♯flatten( d )" := (CANUnop AFlatten d) (at level 50) : algenv_ctxt_scope.                   (* ♯ = \sharp *)
Notation "‵{| d |}" := ((CANUnop AColl) d)  (at level 50) : algenv_ctxt_scope.                        (* ‵ = \baeckprime *)
Notation "‵[| ( s , r ) |]" := ((CANUnop (ARec s)) r) (at level 50) : algenv_ctxt_scope.              (* ‵ = \baeckprime *)
Notation "¬π[ s1 ]( r )" := ((CANUnop (ARecRemove s1)) r) (at level 50) : algenv_ctxt_scope.          (* ¬ = \neg and π = \pi *)
Notation "p · r" := ((CANUnop (ADot r)) p) (left associativity, at level 40): algenv_ctxt_scope.      (* · = \cdot *)

Notation "χ⟨ p ⟩( r )" := (CANMap p r) (at level 70) : algenv_ctxt_scope.                              (* χ = \chi *)
Notation "⋈ᵈ⟨ e2 ⟩( e1 )" := (CANMapConcat e2 e1) (at level 70) : algenv_ctxt_scope.                   (* ⟨ ... ⟩ = \rangle ...  \langle *)
Notation "r1 × r2" := (CANProduct r1 r2) (right associativity, at level 70): algenv_ctxt_scope.       (* × = \times *)
Notation "σ⟨ p ⟩( r )" := (CANSelect p r) (at level 70) : algenv_ctxt_scope.                           (* σ = \sigma *)
Notation "r1 ∥ r2" := (CANDefault r1 r2) (right associativity, at level 70): algenv_ctxt_scope.       (* ∥ = \parallel *)
Notation "r1 ◯ r2" := (CANApp r1 r2) (right associativity, at level 60): algenv_ctxt_scope.           (* ◯ = \bigcirc *)

Notation "r1 ◯ₑ r2" := (CANAppEnv r1 r2) (right associativity, at level 60): algenv_ctxt_scope.           (* ◯ = \bigcirc *)

Notation "χᵉ⟨ p ⟩( r )" := (CANMapEnv p r) (at level 70) : algenv_ctxt_scope.                              (* χ = \chi *)

Notation "$ n" := (CNHole n) (at level 50)  : algenv_ctxt_scope.

Notation "X ≡ₑ Y" := (algenv_ctxt_equiv algenv_eq X Y) (at level 90) : algenv_ctxt_scope.

  Hint Rewrite
       @aec_substs_Plug
       @aec_substs_Binop
       @aec_substs_Unop
       @aec_substs_Map
       @aec_substs_MapConcat
       @aec_substs_Product
       @aec_substs_Select
       @aec_substs_Default
       @aec_substs_Either
       @aec_substs_EitherConcat
       @aec_substs_App
       @aec_substs_AppEnv
       @aec_substs_MapEnv : aec_substs.
  
(* 
*** Local Variables: ***
*** coq-load-path: (("../../../coq" "QCert")) ***
*** End: ***
*)
