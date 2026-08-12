/**
 *    bsg_mesh_router_decoder_dor.sv
 *
 *    Dimension ordered routing decoder
 *    
 *    depopulated ruche router.
 */

`include "bsg_defines.sv"

module bsg_mesh_router_decoder_dor
  import bsg_noc_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p )
    , parameter `BSG_INV_PARAM(y_cord_width_p )
    , parameter dims_p = 2
    , parameter dirs_lp = (2*dims_p)+1
    , parameter ruche_factor_X_p=0
    , parameter ruche_factor_Y_p=0
    // XY_order_p = 1 :  X then Y
    // XY_order_p = 0 :  Y then X
    , parameter XY_order_p = 1
    , parameter depopulated_p = 1
    , parameter from_p = {dirs_lp{1'b0}}  // one-hot, indicates which direction is the input coming from.

    , parameter debug_p = 1
  )
  (
    input clk_i         // debug only
    , input reset_i     // debug only

    //, input v_i

    , input [x_cord_width_p-1:0] x_dirs_i
    , input [y_cord_width_p-1:0] y_dirs_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

	// ADDED INPUTS
    , input [2:0] entropy_val
    , input [5:0] router_id_val

    , output [dirs_lp-1:0] req_o
  );


  // check parameters

`ifndef BSG_HIDE_FROM_SYNTHESIS
  initial begin
    if (ruche_factor_X_p > 0) begin
      assert(dims_p > 2) else $fatal(1, "ruche in X direction requires dims_p greater than 2.");
    end
    
    if (ruche_factor_Y_p > 0) begin
      assert(dims_p > 3) else $fatal(1, "ruche in Y direction requires dims_p greater than 3.");
    end

    assert($countones(from_p) == 1) else $fatal(1, "Must define from_p as one-hot value.");

    assert(ruche_factor_X_p < (1<<x_cord_width_p)) else $fatal(1, "ruche factor in X direction is too large");
    assert(ruche_factor_Y_p < (1<<y_cord_width_p)) else $fatal(1, "ruche factor in Y direction is too large");
  end
`endif




  // compare coordinates
  wire x_eq = (x_dirs_i == my_x_i);
  wire y_eq = (y_dirs_i == my_y_i);
  wire x_gt = x_dirs_i > my_x_i;
  wire y_gt = y_dirs_i > my_y_i;
  wire x_lt = ~x_gt & ~x_eq;
  wire y_lt = ~y_gt & ~y_eq;

  // valid signal
  logic [dirs_lp-1:0] req;
  assign req_o = req;


  // P-port
  assign req[P] = x_eq & y_eq;

  // Signals associated with hashing
  // Parameters defined by your constraints:
  // N_ENTROPY_BITS = 3 -> (1 << 3) - 1 = 8'h07
  // N_ROUTER_ID_BITS = 6
  // W = max(3, 6) + 2 = 8
  localparam int W = 8;
  localparam bit [7:0] HASH_CONST = 8'hB9; // Truncated to 8 bits for W=8

  // Use hashing of the packet entropy and router ID to generate
  // a pseudo-random bit for tie-breaking in the routing decision.
  // Old, slow version for hashing:
  /*
  wire [7:0] z_pre    = ({5'b0, entropy_val} ^ {2'b0, router_id_val});
  wire [7:0] z_mix    = (z_pre * HASH_CONST);
  wire [7:0] hash_res = (z_mix * 2) >> W;
  wire       decision_bit = hash_res[0];
  */

  // New, faster version for hashing:
  wire [5:0] z_pre = {router_id_val[5:3], entropy_val[2:0] ^ router_id_val[2:0]};
  wire [7:0] z_mix = z_pre * HASH_CONST;
  wire decision_bit = z_mix[7];

  // We implement the west-first turn model.
  // We remove the existing code for ruche networks as we assume a 2D mesh
  // without ruche channels.
  // First ?: are we in the same x coordinate? If so, we can route north/south
  // Second ?: are we in the same y coordinate? If so, we can route east/west
  // Third ?: do we need to route to west? If so, we route west (west-first TM)
  assign req[N] = x_eq ? y_lt : (y_eq ? 1'b0 : (x_lt ? 1'b0 : (decision_bit ? y_lt : 1'b0)));
  assign req[S] = x_eq ? y_gt : (y_eq ? 1'b0 : (x_lt ? 1'b0 : (decision_bit ? y_gt : 1'b0)));
  assign req[W] = x_eq ? 1'b0 : (y_eq ? x_lt : (x_lt ? 1'b1 : (decision_bit ? 1'b0 : x_lt)));
  assign req[E] = x_eq ? 1'b0 : (y_eq ? x_gt : (x_lt ? 1'b0 : (decision_bit ? 1'b1 : x_gt)));


`ifndef BSG_HIDE_FROM_SYNTHESIS
  if (debug_p) begin
    always_ff @ (negedge clk_i) begin
      if (~reset_i) begin
        assert($countones(req_o) < 2)
          else $fatal(1, "multiple req_o detected. %b", req_o);
      end
    end
  end
  else begin
    wire unused0 = clk_i;
    wire unused1 = reset_i;
  end
`endif




endmodule

`BSG_ABSTRACT_MODULE(bsg_mesh_router_decoder_dor)

