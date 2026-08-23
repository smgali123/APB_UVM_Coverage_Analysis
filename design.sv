// APB Interface
interface apb_if(input logic pclk);
  logic [31:0] paddr;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic        psel;
  logic        penable;
endinterface

// Dummy APB Slave
module apb_slave (apb_if vif);
  always @(posedge vif.pclk) begin
    // Default values
    vif.pready <= 0;
    vif.pslverr <= 0;

    // Jab master SETUP phase ke baad ENABLE phase mein aaye
    if (vif.psel && vif.penable) begin
      vif.pready <= 1; // Immediately ready kar diya
      if (!vif.pwrite) begin
        // Agar read operation hai, toh dummy data return karein
        vif.prdata <= vif.paddr + 32'hCAFE; 
      end
    end
  end
endmodule
