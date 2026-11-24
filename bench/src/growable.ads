--  Minimal growable array (capacity doubling), standing in for the vector a
--  heap based runtime layer would provide.

generic
   type Element is private;
package Growable is

   type Element_Array is array (Positive range <>) of Element;
   type Array_Access is access Element_Array;

   type Vector is record
      Data  : Array_Access;
      Count : Natural := 0;
   end record;

   procedure Append (V : in out Vector; E : Element)
   with Inline;

   procedure Destroy (V : in out Vector);

end Growable;
