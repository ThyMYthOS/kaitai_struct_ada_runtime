--  Memory management strategies for the result of parsing a list of
--  tag/length/payload records.  Each strategy is measured for building the
--  result, traversing it, picking single elements and tearing it down.

package Strategies is

   type Strategy is
     (Lazy,            --  nothing stored, records are re-parsed on access
      Index_Arena,     --  preallocated array of nodes, payload as slice
      Index_Owned,     --  as above, payload copied into a byte arena
      Vector_Values,   --  growable array of nodes on the heap, payload as slice
      Vector_Reserved, --  heap array of nodes, capacity reserved up front
      Ada_Vector,      --  Ada.Containers.Vectors of nodes, payload as slice
      Ptr_Malloc,      --  one heap object per node, payload as slice
      Ptr_Pool,        --  one object per node from a bump storage pool
      Ptr_Pool_Kept,   --  as above, the pool keeps its memory between runs
      Ptr_Subpool,     --  one object per node from an Ada 2012 subpool
      Owned_Malloc,    --  node and payload copy as separate heap objects
      Owned_Pool,      --  node and payload copy from a bump storage pool
      Owned_Pool_Kept, --  as above, the pool keeps its memory between runs
      Owned_Subpool);  --  node and payload copy from an Ada 2012 subpool

   --  Phases limits how far each repetition goes, so that the cost of a single
   --  phase can be obtained as the difference of two runs when counting
   --  instructions: 0 = generate the input only, 1 = build, 2 = and traverse,
   --  3 = and pick, 4 = and tear down.
   subtype Phase_Count is Natural range 0 .. 4;

   procedure Run
     (Which : Strategy; Records : Positive; Max_Payload : Natural; Reps : Positive; Phases : Phase_Count := 4);

end Strategies;
