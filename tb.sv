import uvm_pkg::*;
`include "uvm_macros.svh"

// ---------------------------------------------------------
// 1. Transaction Item
// ---------------------------------------------------------
class apb_trans extends uvm_sequence_item;
  rand bit [31:0] paddr;
  rand bit        pwrite;
  rand bit [31:0] pwdata;
       bit [31:0] prdata;
       bit        pready;
       bit        pslverr;

  constraint addr_c { paddr inside {[32'h0 : 32'h2FFF]}; paddr % 4 == 0; }

  `uvm_object_utils_begin(apb_trans)
    `uvm_field_int(paddr, UVM_ALL_ON)
    `uvm_field_int(pwrite, UVM_ALL_ON)
    `uvm_field_int(pwdata, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_trans");
    super.new(name);
  endfunction
endclass

// ---------------------------------------------------------
// 2. Sequence (Generates 10 random transactions)
// ---------------------------------------------------------
class apb_sequence extends uvm_sequence #(apb_trans);
  `uvm_object_utils(apb_sequence)
  function new(string name = "apb_sequence"); super.new(name); endfunction

  virtual task body();
    repeat(10) begin
      req = apb_trans::type_id::create("req");
      start_item(req);
      assert(req.randomize());
      finish_item(req);
    end
  endtask
endclass

// ---------------------------------------------------------
// 3. Driver (Drives signals to Interface)
// ---------------------------------------------------------
class apb_driver extends uvm_driver #(apb_trans);
  `uvm_component_utils(apb_driver)
  virtual apb_if vif;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Driver failed to get virtual interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.psel <= 0; vif.penable <= 0;
    forever begin
      seq_item_port.get_next_item(req);
      
      // SETUP Phase
      @(posedge vif.pclk);
      vif.paddr <= req.paddr;
      vif.pwrite <= req.pwrite;
      if (req.pwrite) vif.pwdata <= req.pwdata;
      vif.psel <= 1;
      vif.penable <= 0;

      // ACCESS Phase
      @(posedge vif.pclk);
      vif.penable <= 1;
      
      // Wait for PREADY
      wait(vif.pready);
      
      // Clear bus
      @(posedge vif.pclk);
      vif.psel <= 0;
      vif.penable <= 0;
      
      seq_item_port.item_done();
    end
  endtask
endclass

// ---------------------------------------------------------
// 4. Monitor (Observes bus & broadcasts to Subscriber)
// ---------------------------------------------------------
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)
  virtual apb_if vif;
  uvm_analysis_port #(apb_trans) ap_port;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_port = new("ap_port", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Monitor failed to get virtual interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_trans tr;
    forever begin
      @(posedge vif.pclk);
      if (vif.psel && !vif.penable) begin
        tr = apb_trans::type_id::create("tr");
        tr.paddr = vif.paddr;
        tr.pwrite = vif.pwrite;
        
        @(posedge vif.pclk);
        while (!vif.pready) @(posedge vif.pclk);
        
        ap_port.write(tr); // Broadcast!
      end
    end
  endtask
endclass

// ---------------------------------------------------------
// 5. Coverage Subscriber
// ---------------------------------------------------------
class apb_subscriber extends uvm_subscriber #(apb_trans);
  `uvm_component_utils(apb_subscriber)
  apb_trans tr;

  covergroup apb_cg;
    option.per_instance = 1;
    cp_pwrite: coverpoint tr.pwrite { bins read = {0}; bins write = {1}; }
    cp_paddr: coverpoint tr.paddr {
      bins reg1 = {[32'h0 : 32'hFFF]};
      bins reg2 = {[32'h1000 : 32'h2FFF]};
    }
    cross_op_addr: cross cp_pwrite, cp_paddr;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  virtual function void write(apb_trans t);
    $cast(this.tr, t.clone());
    apb_cg.sample();
  endfunction
endclass

// ---------------------------------------------------------
// 6. Agent, Environment & Test
// ---------------------------------------------------------
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)
  apb_driver    drv;
  apb_monitor   mon;
  uvm_sequencer #(apb_trans) seqr;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = apb_driver::type_id::create("drv", this);
    mon = apb_monitor::type_id::create("mon", this);
    seqr = uvm_sequencer#(apb_trans)::type_id::create("seqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass

class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)
  apb_agent      agent;
  apb_subscriber sub;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent", this);
    sub = apb_subscriber::type_id::create("sub", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    agent.mon.ap_port.connect(sub.analysis_export);
  endfunction
endclass

class apb_test extends uvm_test;
  `uvm_component_utils(apb_test)
  apb_env env;
  
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_sequence seq = apb_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.seqr);
    #50;
    phase.drop_objection(this);
  endtask
endclass

// ---------------------------------------------------------
// 7. Top Module (Clock, Instantiation & Waveform Dump)
// ---------------------------------------------------------
module top;
  logic pclk;
  apb_if vif(pclk);
  apb_slave dut(vif);

  // Clock Generation
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // UVM Config & Run
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", vif);
    run_test("apb_test");
  end

  // Waveform Generation!
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, top); // 0 means dump all variables in top module and below
  end
endmodule
