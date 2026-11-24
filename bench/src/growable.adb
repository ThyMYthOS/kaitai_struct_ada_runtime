with Ada.Unchecked_Deallocation;

package body Growable is

   procedure Free is new Ada.Unchecked_Deallocation (Element_Array, Array_Access);

   procedure Grow (V : in out Vector)
   with No_Inline;

   procedure Grow (V : in out Vector) is
      New_Data : constant Array_Access := new Element_Array (1 .. (if V.Data = null then 16 else V.Data'Length * 2));
   begin
      if V.Data /= null then
         New_Data (1 .. V.Count) := V.Data (1 .. V.Count);
         Free (V.Data);
      end if;
      V.Data := New_Data;
   end Grow;

   procedure Append (V : in out Vector; E : Element) is
   begin
      if V.Data = null or else V.Count = V.Data'Last then
         Grow (V);
      end if;
      V.Count := V.Count + 1;
      V.Data (V.Count) := E;
   end Append;

   procedure Destroy (V : in out Vector) is
   begin
      Free (V.Data);
      V.Count := 0;
   end Destroy;

end Growable;
