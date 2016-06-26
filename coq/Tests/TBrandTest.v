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

(** * EXAMPLES manually translated from arl (JRules) *)

Require Import PatternTest.
Require Import BrandTest.
Require Import BasicSystem.

Local Open Scope rule_scope.
Local Open Scope string.

(* This module encodes the examples in sample-rules.txt *)
Section TBrandTest.

  Require Import TrivialModel.
  
  Require Import Program.
  Import ListNotations.
  
  (******* Defining model – should be automatized, but for now *** *)

  Existing Instance trivial_foreign_type.
  Existing Instance CPRModel_relation.
  Program Definition EntityType : rtype
    := Rec Open [] _.

  Program Definition CustomerType : rtype
    := Rec Open [("age", Nat)
                 ; ("cid", Nat)
                 ; ("name", String)] _.

  Program Definition PurchaseType : rtype
    := Rec Open [("cid", Nat)
                 ; ("name", String)
                 ; ("pid", Nat)
                 ; ("quantity", Nat)] _.

  Definition CPTModelTypes :=
    [("Customer", CustomerType)
      ; ("Entity", EntityType)
      ; ("Purchase", PurchaseType)].
  
  Definition CPTContext
    := @mkBrand_context trivial_foreign_type CPRModel_relation CPTModelTypes (eq_refl _).

  Instance CPModel : brand_model
    := mkBrand_model CPRModel_relation CPTContext (eq_refl _) (eq_refl _).

  Require Import TPattern TPatternSugar TRule.
  
  (* Typing for R1 *)

  Ltac brand_solver :=
    match goal with
      |  [|- sub_brand ?l ?b ?c ] => 
         case_eq (sub_brand_dec l b c); trivial; try discriminate
    end.

  Lemma R1typed :
    rule_type (Brand (singleton "Entity")) (Coll String) R1.
  Proof.
    Hint Resolve PTCast.
    
    unfold R1.
    unfold rule_type; simpl.
    econstructor; eauto.
    econstructor.
    repeat econstructor; eauto.
    econstructor; eauto.
    2: econstructor; eauto.
    econstructor; eauto.
    - econstructor.
      + econstructor.
        * econstructor; eauto.
          econstructor; eauto.
        * econstructor; eauto.
      + econstructor.
        * econstructor; eauto.
          econstructor; eauto.
        * econstructor.
        * { econstructor.
            - apply @PTassert.
              econstructor; eauto.
              + econstructor; eauto.
                * econstructor; eauto.
                  econstructor; eauto.
                * econstructor; eauto; [| econstructor ].
                  econstructor; eauto.
                  econstructor; eauto.
                  rewrite brands_type_singleton.
                  simpl.
                  econstructor; reflexivity.
              + econstructor.
                simpl. eapply @dtnat.
            - reflexivity.
            - econstructor; eauto.
              + econstructor; eauto.
              + econstructor; eauto.
          }
    - reflexivity.
    - econstructor; eauto.
      econstructor; eauto.
      + econstructor; [| econstructor ].
        econstructor; simpl.
        eapply @dtstring.
      + econstructor; [| econstructor ].
        repeat (econstructor; eauto).
        rewrite brands_type_singleton.
        simpl. econstructor. reflexivity.
      + econstructor.
    Grab Existential Variables.
    eauto. eauto. eauto. eauto.
  Qed.

End TBrandTest.


(* 
*** Local Variables: ***
*** coq-load-path: (("../../coq" "QCert")) ***
*** End: ***
*)
