with Bits_Tests;
with Byte_Arrays_Tests;
with Decoding_Tests;
with Examples_Tests;
with Sample_Parser_Tests;
with Streams_Tests;
with Substreams_Tests;
with Test_Support;

procedure All_Tests is
begin
   Decoding_Tests.Run;
   Streams_Tests.Run;
   Bits_Tests.Run;
   Byte_Arrays_Tests.Run;
   Substreams_Tests.Run;
   Sample_Parser_Tests.Run;
   Examples_Tests.Run;
   Test_Support.Summary;
end All_Tests;
