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

Section BinaryOperatorsSem.
  Require Import String.
  Require Import List.
  Require Import Compare_dec.
  Require Import ZArith.
  Require Import Utils.
  Require Import BrandRelation.
  Require Import ForeignData.
  Require Import RData.
  Require Import RDataNorm.
  Require Import RRelation.
  Require Import OperatorsUtils.
  Require Import ForeignOperators.
  Require Export BinaryOperators.
  
  (* Algebra Unary/Binary Ops *)

  Definition arith_binary_op_eval (op:arith_binary_op) (z1 z2:Z) : Z :=
    match op with
    | ArithPlus => Z.add z1 z2
    | ArithMinus=> Z.sub z1 z2
    | ArithMult => Z.mul z1 z2
    | ArithMin => Z.min z1 z2
    | ArithMax => Z.max z1 z2
    | ArithDivide=> Z.quot z1 z2
    | ArithRem => Z.rem z1 z2
    end.

  Context (h:brand_relation_t).
  Context {fdata:foreign_data}.
  Context {fbop:foreign_binary_op}.

  Definition binary_op_eval (bop:binary_op) (d1 d2:data) : option data :=
    match bop with
    | OpEqual => unbdata (fun x y => if data_eq_dec x y then true else false) d1 d2
    | OpRecConcat =>
      match d1, d2 with
      | (drec r1), (drec r2) => Some (drec (rec_sort (r1++r2)))
      | _, _ => None
      end
    | OpRecMerge =>
      match d1, d2 with
      | (drec r1), (drec r2) =>
        match merge_bindings r1 r2 with
        | Some x => Some (dcoll ((drec x) :: nil))
        | None => Some (dcoll nil)
        end
      | _, _ => None
      end
    | OpAnd => unbdbool andb d1 d2
    | OpOr => unbdbool orb d1 d2
    | OpLt => unbdnat (fun x y => if Z_lt_dec x y then true else false) d1 d2
    | OpLe => unbdnat (fun x y => if Z_le_dec x y then true else false) d1 d2
    | OpBagUnion => rondcoll2 bunion d1 d2
    | OpBagDiff => rondcoll2 (@bminus data data_eq_dec) d1 d2
    | OpBagMin => rondcoll2 (@bmin data data_eq_dec) d1 d2
    | OpBagMax => rondcoll2 (@bmax data data_eq_dec) d1 d2
    | OpContains =>
      ondcoll (fun l =>
                 if in_dec data_eq_dec d1 l
                 then dbool true else dbool false) d2
    | OpStringConcat => unsdstring append d1 d2
    | OpArithBinary op =>
        match d1, d2 with
        | dnat n1, dnat n2 => Some (dnat (arith_binary_op_eval op n1 n2))
        | _, _ => None
        end
    | OpForeignBinary fb => foreign_binary_op_interp h fb d1 d2
    end.

  Lemma binary_op_eval_normalized {b d1 d2 o} :
    binary_op_eval b d1 d2 = Some o ->
    data_normalized h d1 -> data_normalized h d2 ->
    data_normalized h o.
  Proof.
    Hint Constructors data_normalized Forall.
    destruct b; simpl; intros;
      try solve [
            unfold rondcoll2 in *;
            destruct d1; simpl in *; try discriminate;
            destruct d2; simpl in *; try discriminate;
            inversion H; subst;
            eauto 1;
            inversion H; subst;
            constructor;
            inversion H0; inversion H1; subst;
            solve [apply bunion_Forall; trivial
                  | apply bminus_Forall; trivial
                  | apply bmin_Forall; trivial
                  | apply bmax_Forall; trivial]
          ].
    - do 2 match_destr_in H.
      inversion H; clear H; subst.
      apply data_normalized_rec_sort_app; trivial.
    - do 2 match_destr_in H.
      unfold merge_bindings in H.
      destruct (Compat.compatible l l0); inversion H; eauto 2.
      constructor. constructor; trivial.
      apply data_normalized_rec_concat_sort; trivial.
    - destruct d2; simpl in *; try discriminate.
      match_destr_in H; inversion H; eauto.
    - eapply foreign_binary_op_normalized; eauto.
  Qed.
  
End BinaryOperatorsSem.

(* 
 *** Local Variables: ***
 *** coq-load-path: (("../../../coq" "Qcert")) ***
 *** End: ***
 *)
