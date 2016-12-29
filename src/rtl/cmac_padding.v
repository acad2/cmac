//======================================================================
//
// cmac_padding.v
// --------------
// Test logic to generate padding. The format of the padding is
// given in RFC 4493 and the NIST SP 800-38B specs. Basically
// pad the last block with the bits int the lat block followed
// by a one and as many zeros as needed to fill the final
// block. For a message of zero length, the block after padding
// is {1'b1, 127'b0}
//
//
// Author: Joachim Strombergson
// Copyright (c) 2016, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module cmac_padding();

  //----------------------------------------------------------------
  // pad_block()
  //
  // pad a given block in with the given amount of data to generate
  // block ut.
  //----------------------------------------------------------------
  task pad_block(input [6 : 0] length, input [127 : 0] block_in,
                 output [127 : 0] block_out);
    begin : pad
      reg [255 : 0] padded;
      padded = {block_in, 1'b1, 127'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[0])
        padded = {padded[255 : (128 + 1)], 1'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[1])
        padded = {padded[255 : (128 + 2)], 2'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[2])
        padded = {padded[255 : (128 + 4)], 4'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[3])
        padded = {padded[255 : (128 + 8)], 8'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[4])
        padded = {padded[255 : (128 + 16)], 16'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[5])
        padded = {padded[255 : (128 + 32)], 32'b0};
      $display("padded: 0b%0256b", padded);

      if (!length[6])
        padded = {padded[255 : (128 + 64)], 64'b0};
      $display("padded: 0b%0256b", padded);

      block_out = padded[255 : 128];
    end
  endtask // pad_block


  //----------------------------------------------------------------
  // pad_mask()
  //
  // Generate pad mask used by pad_block
  //----------------------------------------------------------------
  task pad_mask(input [6 : 0] length, output [126 : 0] mask);
    begin : gen_mask
      reg [002 : 0] b1;
      reg [006 : 0] b2;
      reg [014 : 0] b3;
      reg [030 : 0] b4;
      reg [062 : 0] b5;
      reg [126 : 0] b6;

      if (length[1])
        b1 = {length[0], {2{1'b1}}};
      else
        b1 = {{2{1'b0}}, length[0]};

      if (length[2])
        b2 = {b1, {4{1'b1}}};
      else
        b2 = {{4{1'b0}}, b1};

      if (length[3])
        b3 = {b2, {8{1'b1}}};
      else
        b3 = {{8{1'b0}}, b2};

      if (length[4])
        b4 = {b3, {16{1'b1}}};
      else
        b4 = {{16{1'b0}}, b3};

      if (length[5])
        b5 = {b4, {32{1'b1}}};
      else
        b5 = {{32{1'b0}}, b4};

      if (length[6])
        b6 = {b5, {64{1'b1}}};
      else
        b6 = {{64{1'b0}}, b5};

      mask = b6;
    end
  endtask // pad_mask


  //----------------------------------------------------------------
  // test_padding
  //----------------------------------------------------------------
  initial
    begin : test_padding
      reg [7 : 0]  length;
      reg [126 : 0] mask;

      reg [127 : 0] block_in;
      reg [127 : 0] block_out;

      block_in = 128'hdeadbeef_01020304_0a0b0c0d_55555555;

      $display("Testing cmac padding");
      $display("--------------------");
      $display("Block before padding:        0b%0128b", block_in);
      for (length = 0 ; length < 128 ; length = length + 1)
        begin
          pad_block(length, block_in, block_out);
          $display("padded block for length %03d: 0b%0128b", length, block_out);
        end
    end // test_padding

endmodule // cmac_padding

//======================================================================
// EOF cmac_padding.v
//======================================================================
