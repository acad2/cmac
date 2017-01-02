//======================================================================
//
// tb_cmac.v
// ---------
// Testbench for CMAC based on AES.
// Testvectors from:
// http://csrc.nist.gov/groups/ST/toolkit/documents/Examples/AES_CMAC.pdf
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

module tb_cmac();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam DEBUG = 0;

  localparam CLK_HALF_PERIOD = 1;
  localparam CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  // The DUT address map.
  localparam ADDR_NAME0       = 8'h00;
  localparam ADDR_NAME1       = 8'h01;
  localparam ADDR_VERSION     = 8'h02;

  localparam ADDR_CTRL        = 8'h08;
  localparam CTRL_INIT_BIT    = 0;
  localparam CTRL_NEXT_BIT    = 1;
  localparam CTRL_FINAL_BIT   = 2;

  localparam ADDR_CONFIG      = 8'h09;
  localparam CTRL_KEYLEN_BIT  = 0;

  localparam ADDR_STATUS      = 8'h0a;
  localparam STATUS_READY_BIT = 0;
  localparam STATUS_VALID_BIT = 1;

  localparam ADDR_KEY0        = 8'h10;
  localparam ADDR_KEY1        = 8'h11;
  localparam ADDR_KEY2        = 8'h12;
  localparam ADDR_KEY3        = 8'h13;
  localparam ADDR_KEY4        = 8'h14;
  localparam ADDR_KEY5        = 8'h15;
  localparam ADDR_KEY6        = 8'h16;
  localparam ADDR_KEY7        = 8'h17;

  localparam ADDR_BLOCK0      = 8'h20;
  localparam ADDR_BLOCK1      = 8'h21;
  localparam ADDR_BLOCK2      = 8'h22;
  localparam ADDR_BLOCK3      = 8'h23;

  localparam ADDR_RESULT0     = 8'h30;
  localparam ADDR_RESULT1     = 8'h31;
  localparam ADDR_RESULT2     = 8'h32;
  localparam ADDR_RESULT3     = 8'h33;

  localparam AES_128_BIT_KEY = 0;
  localparam AES_256_BIT_KEY = 1;

  localparam AES_DECIPHER = 1'b0;
  localparam AES_ENCIPHER = 1'b1;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]  cycle_ctr;
  reg [31 : 0]  error_ctr;
  reg [31 : 0]  tc_ctr;
  reg           tc_correct;

  reg [31 : 0]  read_data;
  reg [127 : 0] result_data;

  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_cs;
  reg           tb_we;
  reg [7  : 0]  tb_address;
  reg [31 : 0]  tb_write_data;
  wire [31 : 0] tb_read_data;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  cmac dut(
           .clk(tb_clk),
           .reset_n(tb_reset_n),
           .cs(tb_cs),
           .we(tb_we),
           .address(tb_address),
           .write_data(tb_write_data),
           .read_data(tb_read_data)
          );


  //----------------------------------------------------------------
  // Concurrent assignments.
  //----------------------------------------------------------------


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;

      #(CLK_PERIOD);

      if (DEBUG)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("cycle: 0x%016x", cycle_ctr);
      $display("State of DUT");
      $display("------------");
      $display("ctrl:   init   = 0x%01x, next = 0x%01x", dut.init, dut.next);
      $display("config: length = 0x%01x ", dut.keylen_reg);
      $display("k1 = 0x%016x, k2 = 0x%016x", dut.k1_reg, dut.k2_reg);
      $display("ready = 0x%01x, valid = 0x%01x, ctrl_state = 0x%02x",
               dut.ready_reg, dut.valid_reg, dut.cmac_ctrl_reg);
      $display("block: 0x%08x, 0x%08x, 0x%08x, 0x%08x",
               dut.block_reg[0], dut.block_reg[1], dut.block_reg[2], dut.block_reg[3]);
      $display("");
      $display("core ready: 0x%01x, core valid: 0x%01x",
               dut.core_ready, dut.core_valid);
      $display("core result: 0x%064x ", dut.core_result);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("TB: Resetting dut.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_results()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_results;
    begin
      $display("");
      if (error_ctr == 0)
        begin
          $display("%02d test completed. All test cases completed successfully.", tc_ctr);
        end
      else
        begin
          $display("%02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_results


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr     = 0;
      error_ctr     = 0;
      tc_ctr        = 0;

      tb_clk        = 0;
      tb_reset_n    = 1;

      tb_cs         = 0;
      tb_we         = 0;
      tb_address    = 8'h0;
      tb_write_data = 32'h0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // inc_tc_ctr
  //----------------------------------------------------------------
  task inc_tc_ctr;
    tc_ctr = tc_ctr + 1;
  endtask // inc_tc_ctr


  //----------------------------------------------------------------
  // inc_error_ctr
  //----------------------------------------------------------------
  task inc_error_ctr;
    error_ctr = error_ctr + 1;
  endtask // inc_error_ctr


  //----------------------------------------------------------------
  // write_word()
  //
  // Write the given word to the DUT using the DUT interface.
  //----------------------------------------------------------------
  task write_word(input [11 : 0]  address,
                  input [31 : 0] word);
    begin
      if (DEBUG)
        begin
          $display("*** Writing 0x%08x to 0x%02x.", word, address);
          $display("");
        end

      tb_address = address;
      tb_write_data = word;
      tb_cs = 1;
      tb_we = 1;
      #(2 * CLK_PERIOD);
      tb_cs = 0;
      tb_we = 0;
    end
  endtask // write_word


  //----------------------------------------------------------------
  // write_block()
  //
  // Write the given block to the dut.
  //----------------------------------------------------------------
  task write_block(input [127 : 0] block);
    begin
      write_word(ADDR_BLOCK0, block[127  :  96]);
      write_word(ADDR_BLOCK1, block[95   :  64]);
      write_word(ADDR_BLOCK2, block[63   :  32]);
      write_word(ADDR_BLOCK3, block[31   :   0]);
    end
  endtask // write_block


  //----------------------------------------------------------------
  // read_word()
  //
  // Read a data word from the given address in the DUT.
  // the word read will be available in the global variable
  // read_data.
  //----------------------------------------------------------------
  task read_word(input [11 : 0]  address);
    begin
      tb_address = address;
      tb_cs = 1;
      tb_we = 0;
      #(CLK_PERIOD);
      read_data = tb_read_data;
      tb_cs = 0;

      if (DEBUG)
        begin
          $display("*** Reading 0x%08x from 0x%02x.", read_data, address);
          $display("");
        end
    end
  endtask // read_word


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag to be set in dut.
  //----------------------------------------------------------------
  task wait_ready;
    begin : wready
      read_word(ADDR_STATUS);
      while (read_data == 0)
        read_word(ADDR_STATUS);
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // read_result()
  //
  // Read the result block in the dut.
  //----------------------------------------------------------------
  task read_result;
    begin
      read_word(ADDR_RESULT0);
      result_data[127 : 096] = read_data;
      read_word(ADDR_RESULT1);
      result_data[095 : 064] = read_data;
      read_word(ADDR_RESULT2);
      result_data[063 : 032] = read_data;
      read_word(ADDR_RESULT3);
      result_data[031 : 000] = read_data;
    end
  endtask // read_result


  //----------------------------------------------------------------
  // init_key()
  //
  // init the key in the dut by writing the given key and
  // key length and then trigger init processing.
  //----------------------------------------------------------------
  task init_key(input [255 : 0] key, input key_length);
    begin
      if (DEBUG)
        begin
          $display("key length: 0x%01x", key_length);
          $display("Initializing key expansion for key: 0x%016x", key);
        end

      write_word(ADDR_KEY0, key[255  : 224]);
      write_word(ADDR_KEY1, key[223  : 192]);
      write_word(ADDR_KEY2, key[191  : 160]);
      write_word(ADDR_KEY3, key[159  : 128]);
      write_word(ADDR_KEY4, key[127  :  96]);
      write_word(ADDR_KEY5, key[95   :  64]);
      write_word(ADDR_KEY6, key[63   :  32]);
      write_word(ADDR_KEY7, key[31   :   0]);

      if (key_length)
        begin
          write_word(ADDR_CONFIG, 8'h02);
        end
      else
        begin
          write_word(ADDR_CONFIG, 8'h00);
        end

      write_word(ADDR_CTRL, 8'h01);
    end
  endtask // init_key


  //----------------------------------------------------------------
  // tc1_reset_registers
  //
  // Check that registers are correctly cleared by reset.
  //----------------------------------------------------------------
  task tc1_check_reset;
    begin : tc1
      integer i;

      inc_tc_ctr();

      tc_correct = 1;
      $display("TC1: Check that reset clears all registers in cmac.");
      reset_dut();

      for (i = 0; i < 4; i = i + 1)
        begin
          if (dut.block_reg[i] != 32'h0)
          begin
            $display("TC1: ERROR - block_reg[%d] not properly reset.", i);
            tc_correct = 0;
            inc_error_ctr();
          end
        end

      for (i = 0; i < 8; i = i + 1)
        begin
          if (dut.key_reg[i] != 32'h0)
          begin
            $display("TC1: ERROR - key_reg[%d] not properly reset.", i);
            tc_correct = 0;
            inc_error_ctr();
          end
        end

      if (dut.k1_reg != 128'h0)
        begin
          $display("TC1: ERROR - k1_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.k2_reg != 128'h0)
        begin
          $display("TC1: ERROR - k2_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.result_reg != 128'h0)
        begin
          $display("TC1: ERROR - result_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.keylen_reg != 0)
        begin
          $display("TC1: ERROR - keylen_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.final_size_reg != 8'h0)
        begin
          $display("TC1: ERROR - final_size_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.valid_reg != 0)
        begin
          $display("TC1: ERROR - valid_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.ready_reg != 1)
        begin
          $display("TC1: ERROR - ready_reg not properly reset.");
          tc_correct = 0;
          inc_error_ctr();
        end

      if (tc_correct)
        $display("TC1: SUCCESS - All registers correctly reset.");
      else
        $display("TC1: NO SUCCESS - Not all registers correctly reset.");

      $display("");
    end
  endtask // cmac_test


  //----------------------------------------------------------------
  // tc2_gen_subkeys
  //
  // Check that subkeys k1 and k2 are correctly generated.
  // The keys and test vectors are from NIST SP 800-38B, D.1.
  //----------------------------------------------------------------
  task tc2_gen_subkeys;
    begin : tc2
      inc_tc_ctr();

      tc_correct = 1;
      $display("TC2: Check that k1 and k2 subkeys are correctly generated.");

      init_key(256'h2b7e1516_28aed2a6_abf71588_09cf4f3c_00000000_00000000_00000000_00000000, 1'b0);
      wait_ready();

      if (DEBUG)
        $display("TC2: k1 = 0x%032x, k2 = 0x%032x", dut.k1_reg, dut.k2_reg);

      if (dut.k1_reg != 128'hfbeed618_35713366_7c85e08f_7236a8de)
        begin
          $display("TC2: ERROR - K1 incorrect. Expected 0xfbeed618_35713366_7c85e08f_7236a8de, got 0x%032x.", dut.k1_reg);
          tc_correct = 0;
          inc_error_ctr();
        end

      if (dut.k2_reg != 128'hf7ddac30_6ae266cc_f90bc11e_e46d513b)
        begin
          $display("TC2: ERROR - K2 incorrect. Expected 0x7ddac30_6ae266cc_f90bc11e_e46d513b, got 0x%032x.", dut.k2_reg);
          tc_correct = 0;
          inc_error_ctr();
        end

      if (tc_correct)
        $display("TC2: SUCCESS - K1 and K2 subkeys correctly generated.");
      else
        $display("TC2: NO SUCCESS - Subkeys not correctly generated.");
    end
  endtask // cmac_test


  //----------------------------------------------------------------
  // tc3_empty_message
  //
  // Check that subkeys k1 and k2 are correctly generated.
  //----------------------------------------------------------------
  task tc3_empty_message;
    begin
    end
  endtask // cmac_test


  //----------------------------------------------------------------
  // main
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : main
      $display("*** Testbench for CMAC started ***");

      init_sim();

      tc1_check_reset();
      tc2_gen_subkeys();
      tc3_empty_message();

      display_test_results();

      $display("*** CMAC simulation done. ***");
      $finish;
    end // main

endmodule // tb_cmac

//======================================================================
// EOF tb_cmac.v
//======================================================================
