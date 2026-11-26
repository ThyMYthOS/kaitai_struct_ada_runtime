--  The measurements of repeat_bench and of its counterpart for the target: how an expression can use the elements of a
--  repetition whose elements have a variable size, which Kaitai.Streams cannot index.  What each variant does is
--  described in README.md.  The loops that stand for the Parse of the parent type are here, so that the procedures
--  that parse one value are not inlined into them by hand.

with Kaitai.Types; use Kaitai.Types;

package Rep_Runs
  with SPARK_Mode, Always_Terminates
is

   type Variant is
     (A_Parse,
      A_Get_First,
      A_Get_Mid,
      A_Get_Last,
      A_Next_All,
      A_Get_All,
      Index_Mod,
      Index_Get,
      Index_Fixed,
      Index_Fixed_Mod,
      Index_Worst,
      Last_Eos,
      Last_Get,
      Last_Kept,
      Prev_Naive,
      Prev_Carried,
      Other_Get,
      Other_Lockstep,
      Empty_Parse,
      Empty_Get,
      Empty_Get_Stop);

   --  The bytes a variant reads
   type Layout is (Rep_L, Index_L, Index_Fixed_L, Index_Worst_L, Last_L, Prev_Self_L, Prev_Other_L, Rep_Empty_L);

   function Layout_Of (V : Variant) return Layout
   is (case V is
         when A_Parse | A_Get_First | A_Get_Mid | A_Get_Last | A_Next_All | A_Get_All => Rep_L,
         when Index_Mod | Index_Get                                                   => Index_L,
         when Index_Worst                                                             => Index_Worst_L,
         when Index_Fixed | Index_Fixed_Mod                                           => Index_Fixed_L,
         when Last_Eos | Last_Get | Last_Kept                                         => Last_L,
         when Prev_Naive | Prev_Carried                                               => Prev_Self_L,
         when Other_Get | Other_Lockstep                                              => Prev_Other_L,
         when Empty_Parse | Empty_Get | Empty_Get_Stop                                => Rep_Empty_L);

   --  The variants that give the same checksum for the same number of elements
   type Group is
     (Parse_G, First_G, Mid_G, Last_G, All_G, Index_G, Worst_G, Tail_G, Prev_G, Other_G, Empty_Parse_G, Empty_Get_G);

   function Group_Of (V : Variant) return Group
   is (case V is
         when A_Parse                                               => Parse_G,
         when A_Get_First                                           => First_G,
         when A_Get_Mid                                             => Mid_G,
         when A_Get_Last                                            => Last_G,
         when A_Next_All | A_Get_All                                => All_G,
         when Index_Mod | Index_Get | Index_Fixed | Index_Fixed_Mod => Index_G,
         when Index_Worst                                           => Worst_G,
         when Last_Eos | Last_Get | Last_Kept                       => Tail_G,
         when Prev_Naive | Prev_Carried                             => Prev_G,
         when Other_Get | Other_Lockstep                            => Other_G,
         when Empty_Parse                                           => Empty_Parse_G,
         when Empty_Get | Empty_Get_Stop                            => Empty_Get_G);

   --  Parses Data Reps times as the variant says and returns the sum of the checksums of the runs
   function Run (V : Variant; Data : Bytes; Reps : Positive) return U64;

end Rep_Runs;
