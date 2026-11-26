package body Rep_Setup is

   procedure Generate (L : Rep_Runs.Layout; N : Natural; Buffer : out Bytes; Used : out Length) is
   begin
      case L is
         when Rep_Runs.Rep_L         =>
            Rep_Data.Fill_Rep (N, Buffer, Used);

         when Rep_Runs.Index_L       =>
            Rep_Data.Fill_Index (N, False, Buffer, Used);

         when Rep_Runs.Index_Fixed_L =>
            Rep_Data.Fill_Index (N, True, Buffer, Used);

         when Rep_Runs.Index_Worst_L =>
            Rep_Data.Fill_Index_Worst (N, Buffer, Used);

         when Rep_Runs.Last_L        =>
            Rep_Data.Fill_Last (N, Buffer, Used);

         when Rep_Runs.Prev_Self_L   =>
            Rep_Data.Fill_Prev_Self (N, Buffer, Used);

         when Rep_Runs.Prev_Other_L  =>
            Rep_Data.Fill_Prev_Other (N, Buffer, Used);

         when Rep_Runs.Rep_Empty_L   =>
            Rep_Data.Fill_Rep_Empty (N, Buffer, Used);
      end case;
   end Generate;

end Rep_Setup;
