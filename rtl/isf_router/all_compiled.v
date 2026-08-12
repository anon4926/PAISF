module bsg_mesh_router_buffered (
	clk_i,
	reset_i,
	link_i,
	link_o,
	my_x_i,
	my_y_i,
	router_id_val_i
);
	parameter width_p = 64;
	parameter x_cord_width_p = 3;
	parameter y_cord_width_p = 3;
	parameter debug_p = 0;
	parameter ruche_factor_X_p = 0;
	parameter ruche_factor_Y_p = 0;
	parameter dims_p = 2;
	parameter dirs_lp = (2 * dims_p) + 1;
	parameter stub_p = {dirs_lp {1'b0}};
	parameter XY_order_p = 1;
	parameter depopulated_p = 1;
	parameter bsg_ready_and_link_sif_width_lp = width_p + 2;
	parameter repeater_output_p = {dirs_lp {1'b0}};
	parameter use_credits_p = {dirs_lp {1'b0}};
	parameter signed [(dirs_lp * 32) - 1:0] fifo_els_p = 160'h0000000800000008000000080000000800000008;
	input clk_i;
	input reset_i;
	input [(dirs_lp * bsg_ready_and_link_sif_width_lp) - 1:0] link_i;
	output wire [(dirs_lp * bsg_ready_and_link_sif_width_lp) - 1:0] link_o;
	input [x_cord_width_p - 1:0] my_x_i;
	input [y_cord_width_p - 1:0] my_y_i;
	input [5:0] router_id_val_i;
	wire [(dirs_lp * (2 + width_p)) - 1:0] link_i_cast;
	wire [(dirs_lp * (2 + width_p)) - 1:0] link_o_cast;
	assign link_i_cast = link_i;
	assign link_o = link_o_cast;
	wire [dirs_lp - 1:0] fifo_valid;
	wire [(dirs_lp * width_p) - 1:0] fifo_data;
	wire [dirs_lp - 1:0] fifo_yumi;
	genvar i;
	generate
		if (debug_p) begin : genblk1
			for (i = 0; i < dirs_lp; i = i + 1) begin : genblk1
				always @(negedge clk_i)
					$display("%m x=%d y=%d SNEWP[%d] v_i=%b ready_o=%b v_o=%b ready_i=%b %b", my_x_i, my_y_i, i, link_i_cast[(i * (2 + width_p)) + (width_p + 1)], link_o_cast[(i * (2 + width_p)) + (width_p + 0)], link_o_cast[(i * (2 + width_p)) + (width_p + 1)], link_i_cast[(i * (2 + width_p)) + (width_p + 0)], link_i[i * bsg_ready_and_link_sif_width_lp+:bsg_ready_and_link_sif_width_lp]);
			end
		end
	endgenerate
	function automatic signed [width_p - 1:0] sv2v_cast_4B3A8_signed;
		input reg signed [width_p - 1:0] inp;
		sv2v_cast_4B3A8_signed = inp;
	endfunction
	generate
		for (i = 0; i < dirs_lp; i = i + 1) begin : rof
			if (stub_p[i]) begin : fi
				assign fifo_data[i * width_p+:width_p] = sv2v_cast_4B3A8_signed(0);
				assign fifo_valid[i] = 1'b0;
				assign link_o_cast[(i * (2 + width_p)) + (width_p + 0)] = 1'b0;
				always @(negedge clk_i)
					;
			end
			else begin : fi
				wire fifo_ready_lo;
				bsg_fifo_1r1w_small #(
					.width_p(width_p),
					.els_p(fifo_els_p[i * 32+:32])
				) fifo(
					.clk_i(clk_i),
					.reset_i(reset_i),
					.v_i(link_i_cast[(i * (2 + width_p)) + (width_p + 1)]),
					.data_i(link_i_cast[(i * (2 + width_p)) + (width_p - 1)-:width_p]),
					.ready_param_o(fifo_ready_lo),
					.v_o(fifo_valid[i]),
					.data_o(fifo_data[i * width_p+:width_p]),
					.yumi_i(fifo_yumi[i])
				);
				if (use_credits_p[i]) begin : cr
					bsg_dff_reset #(
						.width_p(1),
						.reset_val_p(0)
					) dff0(
						.clk_i(clk_i),
						.reset_i(reset_i),
						.data_i(fifo_yumi[i]),
						.data_o(link_o_cast[(i * (2 + width_p)) + (width_p + 0)])
					);
					always @(negedge clk_i)
						if (~reset_i) begin
							if (link_i_cast[(i * (2 + width_p)) + (width_p + 1)])
								;
						end
				end
				else begin : genblk1
					assign link_o_cast[(i * (2 + width_p)) + (width_p + 0)] = fifo_ready_lo;
				end
			end
		end
	endgenerate
	wire [dirs_lp - 1:0] valid_lo;
	wire [(dirs_lp * width_p) - 1:0] data_lo;
	wire [dirs_lp - 1:0] ready_li;
	generate
		for (i = 0; i < dirs_lp; i = i + 1) begin : rof2
			assign link_o_cast[(i * (2 + width_p)) + (width_p + 1)] = valid_lo[i];
			if (repeater_output_p[i] & ~stub_p[i]) begin : macro
				wire [width_p - 1:0] tmp;
				initial $display("%m with buffers on %d", i);
				bsg_inv #(
					.width_p(width_p),
					.vertical_p(i < 3)
				) data_lo_inv(
					.i(data_lo[i * width_p+:width_p]),
					.o(tmp)
				);
				bsg_inv #(
					.width_p(width_p),
					.vertical_p(i < 3)
				) data_lo_rep(
					.i(tmp),
					.o(link_o_cast[(i * (2 + width_p)) + (width_p - 1)-:width_p])
				);
			end
			else begin : genblk1
				assign link_o_cast[(i * (2 + width_p)) + (width_p - 1)-:width_p] = data_lo[i * width_p+:width_p];
			end
			assign ready_li[i] = link_i_cast[(i * (2 + width_p)) + (width_p + 0)];
		end
	endgenerate
	bsg_mesh_router #(
		.width_p(width_p),
		.x_cord_width_p(x_cord_width_p),
		.y_cord_width_p(y_cord_width_p),
		.ruche_factor_X_p(ruche_factor_X_p),
		.ruche_factor_Y_p(ruche_factor_Y_p),
		.dims_p(dims_p),
		.XY_order_p(XY_order_p),
		.depopulated_p(depopulated_p)
	) bmr(
		.clk_i(clk_i),
		.reset_i(reset_i),
		.v_i(fifo_valid),
		.data_i(fifo_data),
		.yumi_o(fifo_yumi),
		.v_o(valid_lo),
		.data_o(data_lo),
		.ready_and_i(ready_li),
		.my_x_i(my_x_i),
		.my_y_i(my_y_i),
		.router_id_val_i(router_id_val_i)
	);
endmodule
module bsg_mesh_router_buffered__abstract;
	
endmodule
module bsg_fifo_1r1w_small (
	clk_i,
	reset_i,
	v_i,
	ready_param_o,
	data_i,
	v_o,
	data_o,
	yumi_i
);
	parameter width_p = 0;
	parameter els_p = 0;
	parameter harden_p = 0;
	parameter ready_THEN_valid_p = 0;
	input clk_i;
	input reset_i;
	input v_i;
	output wire ready_param_o;
	input [width_p - 1:0] data_i;
	output wire v_o;
	output wire [width_p - 1:0] data_o;
	input yumi_i;
	generate
		if (harden_p == 0) begin : unhardened
			if (els_p == 2) begin : tf
				bsg_two_fifo #(
					.width_p(width_p),
					.ready_THEN_valid_p(ready_THEN_valid_p)
				) twof(
					.ready_param_o(ready_param_o),
					.clk_i(clk_i),
					.reset_i(reset_i),
					.data_i(data_i),
					.v_i(v_i),
					.v_o(v_o),
					.data_o(data_o),
					.yumi_i(yumi_i)
				);
			end
			else begin : un
				bsg_fifo_1r1w_small_unhardened #(
					.width_p(width_p),
					.els_p(els_p),
					.ready_THEN_valid_p(ready_THEN_valid_p)
				) fifo(
					.clk_i(clk_i),
					.reset_i(reset_i),
					.v_i(v_i),
					.ready_param_o(ready_param_o),
					.data_i(data_i),
					.v_o(v_o),
					.data_o(data_o),
					.yumi_i(yumi_i)
				);
			end
		end
		else begin : hardened
			bsg_fifo_1r1w_small_hardened #(
				.width_p(width_p),
				.els_p(els_p),
				.ready_THEN_valid_p(ready_THEN_valid_p)
			) fifo(.*);
		end
	endgenerate
endmodule
module bsg_fifo_1r1w_small__abstract;
	
endmodule
module bsg_mesh_router (
	clk_i,
	reset_i,
	data_i,
	v_i,
	yumi_o,
	ready_and_i,
	data_o,
	v_o,
	my_x_i,
	my_y_i,
	router_id_val_i
);
	parameter width_p = 0;
	parameter x_cord_width_p = 0;
	parameter y_cord_width_p = 0;
	parameter ruche_factor_X_p = 0;
	parameter ruche_factor_Y_p = 0;
	parameter dims_p = 2;
	parameter out_dirs_lp = (2 * dims_p) + 1;
	parameter in_dirs_lp = out_dirs_lp;
	parameter XY_order_p = 1;
	parameter depopulated_p = 1;
	localparam [80:0] bsg_mesh_router_pkg_FullRuche_FullyPopulated_StrictXY = 81'b011101111101110111000100001001000001001101111001110111000100011001000101111111111;
	localparam [80:0] bsg_mesh_router_pkg_FullRuche_FullyPopulated_StrictYX = 81'b010000001100000001110111011111011101010001001100010001110011011110011101111111111;
	localparam [80:0] bsg_mesh_router_pkg_FullRuche_StrictXY = 81'b010001000100010000000100001001000001000001111000010111000100011001000101110011111;
	localparam [80:0] bsg_mesh_router_pkg_FullRuche_StrictYX = 81'b010000001100000001000100010001000100010001001100010001000011011000011101001111111;
	localparam [48:0] bsg_mesh_router_pkg_HalfRucheX_FullyPopulated_StrictXY = 49'b0100001100000111011111110111010001110001011111111;
	localparam [48:0] bsg_mesh_router_pkg_HalfRucheX_FullyPopulated_StrictYX = 49'b0111011101110100010010010001001101100111011111111;
	localparam [48:0] bsg_mesh_router_pkg_HalfRucheX_StrictXY = 49'b0100001100000100011110010111010001110001010011111;
	localparam [48:0] bsg_mesh_router_pkg_HalfRucheX_StrictYX = 49'b0100010100010000010010010001001101100111011111111;
	localparam [24:0] bsg_mesh_router_pkg_StrictXY = 25'b0111110111000110010111111;
	localparam [24:0] bsg_mesh_router_pkg_StrictYX = 25'b0100110001110111110111111;
	parameter [(out_dirs_lp * in_dirs_lp) - 1:0] routing_matrix_p = (dims_p == 2 ? (XY_order_p ? bsg_mesh_router_pkg_StrictXY : bsg_mesh_router_pkg_StrictYX) : (dims_p == 3 ? (depopulated_p ? (XY_order_p ? bsg_mesh_router_pkg_HalfRucheX_StrictXY : bsg_mesh_router_pkg_HalfRucheX_StrictYX) : (XY_order_p ? bsg_mesh_router_pkg_HalfRucheX_FullyPopulated_StrictXY : bsg_mesh_router_pkg_HalfRucheX_FullyPopulated_StrictYX)) : (dims_p == 4 ? (depopulated_p ? (XY_order_p ? bsg_mesh_router_pkg_FullRuche_StrictXY : bsg_mesh_router_pkg_FullRuche_StrictYX) : (XY_order_p ? bsg_mesh_router_pkg_FullRuche_FullyPopulated_StrictXY : bsg_mesh_router_pkg_FullRuche_FullyPopulated_StrictYX)) : "inv")));
	parameter debug_p = 0;
	input clk_i;
	input reset_i;
	input [(in_dirs_lp * width_p) - 1:0] data_i;
	input [in_dirs_lp - 1:0] v_i;
	output wire [in_dirs_lp - 1:0] yumi_o;
	input [out_dirs_lp - 1:0] ready_and_i;
	output wire [(out_dirs_lp * width_p) - 1:0] data_o;
	output wire [out_dirs_lp - 1:0] v_o;
	input [x_cord_width_p - 1:0] my_x_i;
	input [y_cord_width_p - 1:0] my_y_i;
	input [5:0] router_id_val_i;
	wire [(in_dirs_lp * x_cord_width_p) - 1:0] x_dirs;
	wire [(in_dirs_lp * y_cord_width_p) - 1:0] y_dirs;
	wire [(in_dirs_lp * 3) - 1:0] entropy_vals;
	genvar i;
	generate
		for (i = 0; i < in_dirs_lp; i = i + 1) begin : genblk1
			assign x_dirs[i * x_cord_width_p+:x_cord_width_p] = data_i[i * width_p+:x_cord_width_p];
			assign y_dirs[i * y_cord_width_p+:y_cord_width_p] = data_i[(i * width_p) + x_cord_width_p+:y_cord_width_p];
			assign entropy_vals[i * 3+:3] = data_i[(i * width_p) + (x_cord_width_p + y_cord_width_p)+:3];
		end
	endgenerate
	wire [(in_dirs_lp * out_dirs_lp) - 1:0] req;
	wire [(out_dirs_lp * in_dirs_lp) - 1:0] req_t;
	function automatic signed [out_dirs_lp - 1:0] sv2v_cast_6AEB1_signed;
		input reg signed [out_dirs_lp - 1:0] inp;
		sv2v_cast_6AEB1_signed = inp;
	endfunction
	generate
		for (i = 0; i < in_dirs_lp; i = i + 1) begin : dor
			wire [out_dirs_lp - 1:0] temp_req;
			bsg_mesh_router_decoder_dor #(
				.x_cord_width_p(x_cord_width_p),
				.y_cord_width_p(y_cord_width_p),
				.ruche_factor_X_p(ruche_factor_X_p),
				.ruche_factor_Y_p(ruche_factor_Y_p),
				.dims_p(dims_p),
				.XY_order_p(XY_order_p),
				.from_p(sv2v_cast_6AEB1_signed(1 << (i < out_dirs_lp ? i : 3'd0))),
				.depopulated_p(depopulated_p),
				.debug_p(debug_p)
			) dor_decoder(
				.clk_i(clk_i),
				.reset_i(reset_i),
				.x_dirs_i(x_dirs[i * x_cord_width_p+:x_cord_width_p]),
				.y_dirs_i(y_dirs[i * y_cord_width_p+:y_cord_width_p]),
				.my_x_i(my_x_i),
				.my_y_i(my_y_i),
				.entropy_val(entropy_vals[i * 3+:3]),
				.router_id_val(router_id_val_i),
				.req_o(temp_req)
			);
			assign req[i * out_dirs_lp+:out_dirs_lp] = {out_dirs_lp {v_i[i]}} & temp_req;
		end
	endgenerate
	bsg_transpose #(
		.width_p(out_dirs_lp),
		.els_p(in_dirs_lp)
	) req_tp(
		.i(req),
		.o(req_t)
	);
	wire [(out_dirs_lp * in_dirs_lp) - 1:0] yumi_lo;
	wire [(in_dirs_lp * out_dirs_lp) - 1:0] yumi_lo_t;
	generate
		for (i = 0; i < out_dirs_lp; i = i + 1) begin : xbar
			localparam input_els_lp = (in_dirs_lp < 65 ? 1'b0 : {((0 >= ((out_dirs_lp * in_dirs_lp) - 1) ? i * in_dirs_lp : ((i * in_dirs_lp) + in_dirs_lp) - 1) >= (0 >= ((out_dirs_lp * in_dirs_lp) - 1) ? ((i * in_dirs_lp) + in_dirs_lp) - 1 : i * in_dirs_lp) ? ((0 >= ((out_dirs_lp * in_dirs_lp) - 1) ? i * in_dirs_lp : ((i * in_dirs_lp) + in_dirs_lp) - 1) - (0 >= ((out_dirs_lp * in_dirs_lp) - 1) ? ((i * in_dirs_lp) + in_dirs_lp) - 1 : i * in_dirs_lp)) + 1 : ((0 >= ((out_dirs_lp * in_dirs_lp) - 1) ? ((i * in_dirs_lp) + in_dirs_lp) - 1 : i * in_dirs_lp) - (0 >= ((out_dirs_lp * in_dirs_lp) - 1) ? i * in_dirs_lp : ((i * in_dirs_lp) + in_dirs_lp) - 1)) + 1) {1'sbx}}) + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 0) & 1'b1) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 1) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 2) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 3) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 4) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 5) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 6) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 7) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 8) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 9) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 10) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 11) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 12) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 13) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 14) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 15) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 16) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 17) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 18) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 19) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 20) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 21) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 22) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 23) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 24) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 25) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 26) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 27) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 28) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 29) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 30) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 31) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 32) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 33) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 34) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 35) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 36) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 37) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 38) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 39) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 40) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 41) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 42) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 43) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 44) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 45) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 46) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 47) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 48) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 49) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 50) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 51) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 52) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 53) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 54) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 55) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 56) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 57) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 58) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 59) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 60) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 61) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 62) & 1'b1)) + ((routing_matrix_p[i * in_dirs_lp+:in_dirs_lp] >> 63) & 1'b1));
			wire [(input_els_lp * width_p) - 1:0] conc_data;
			wire [input_els_lp - 1:0] conc_req;
			wire [input_els_lp - 1:0] grants;
			bsg_array_concentrate_static #(
				.pattern_els_p(routing_matrix_p[i * in_dirs_lp+:in_dirs_lp]),
				.width_p(width_p)
			) conc0(
				.i(data_i),
				.o(conc_data)
			);
			bsg_concentrate_static #(.pattern_els_p(routing_matrix_p[i * in_dirs_lp+:in_dirs_lp])) conc1(
				.i(req_t[i * in_dirs_lp+:in_dirs_lp]),
				.o(conc_req)
			);
			assign v_o[i] = |conc_req;
			bsg_arb_round_robin #(.width_p(input_els_lp)) rr(
				.clk_i(clk_i),
				.reset_i(reset_i),
				.reqs_i(conc_req),
				.grants_o(grants),
				.yumi_i(v_o[i] & ready_and_i[i])
			);
			bsg_mux_one_hot #(
				.els_p(input_els_lp),
				.width_p(width_p)
			) data_mux(
				.data_i(conc_data),
				.sel_one_hot_i(grants),
				.data_o(data_o[i * width_p+:width_p])
			);
			bsg_unconcentrate_static #(
				.pattern_els_p(routing_matrix_p[i * in_dirs_lp+:in_dirs_lp]),
				.unconnected_val_p(1'b0)
			) unconc0(
				.i(grants & {input_els_lp {ready_and_i[i]}}),
				.o(yumi_lo[i * in_dirs_lp+:in_dirs_lp])
			);
		end
	endgenerate
	bsg_transpose #(
		.width_p(in_dirs_lp),
		.els_p(out_dirs_lp)
	) yumi_tp(
		.i(yumi_lo),
		.o(yumi_lo_t)
	);
	generate
		for (i = 0; i < in_dirs_lp; i = i + 1) begin : genblk4
			assign yumi_o[i] = |yumi_lo_t[i * out_dirs_lp+:out_dirs_lp];
		end
		if (debug_p) begin : genblk5
			always @(negedge clk_i)
				if (~reset_i) begin : sv2v_autoblock_1
					integer i;
					for (i = 0; i < in_dirs_lp; i = i + 1)
						;
				end
		end
	endgenerate
endmodule
module bsg_mesh_router__abstract;
	
endmodule
module bsg_unconcentrate_static (
	i,
	o
);
	parameter pattern_els_p = 0;
	parameter width_lp = 1'b0 + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((pattern_els_p >> 0) & 1'b1) + ((pattern_els_p >> 1) & 1'b1)) + ((pattern_els_p >> 2) & 1'b1)) + ((pattern_els_p >> 3) & 1'b1)) + ((pattern_els_p >> 4) & 1'b1)) + ((pattern_els_p >> 5) & 1'b1)) + ((pattern_els_p >> 6) & 1'b1)) + ((pattern_els_p >> 7) & 1'b1)) + ((pattern_els_p >> 8) & 1'b1)) + ((pattern_els_p >> 9) & 1'b1)) + ((pattern_els_p >> 10) & 1'b1)) + ((pattern_els_p >> 11) & 1'b1)) + ((pattern_els_p >> 12) & 1'b1)) + ((pattern_els_p >> 13) & 1'b1)) + ((pattern_els_p >> 14) & 1'b1)) + ((pattern_els_p >> 15) & 1'b1)) + ((pattern_els_p >> 16) & 1'b1)) + ((pattern_els_p >> 17) & 1'b1)) + ((pattern_els_p >> 18) & 1'b1)) + ((pattern_els_p >> 19) & 1'b1)) + ((pattern_els_p >> 20) & 1'b1)) + ((pattern_els_p >> 21) & 1'b1)) + ((pattern_els_p >> 22) & 1'b1)) + ((pattern_els_p >> 23) & 1'b1)) + ((pattern_els_p >> 24) & 1'b1)) + ((pattern_els_p >> 25) & 1'b1)) + ((pattern_els_p >> 26) & 1'b1)) + ((pattern_els_p >> 27) & 1'b1)) + ((pattern_els_p >> 28) & 1'b1)) + ((pattern_els_p >> 29) & 1'b1)) + ((pattern_els_p >> 30) & 1'b1)) + ((pattern_els_p >> 31) & 1'b1)) + ((pattern_els_p >> 32) & 1'b1)) + ((pattern_els_p >> 33) & 1'b1)) + ((pattern_els_p >> 34) & 1'b1)) + ((pattern_els_p >> 35) & 1'b1)) + ((pattern_els_p >> 36) & 1'b1)) + ((pattern_els_p >> 37) & 1'b1)) + ((pattern_els_p >> 38) & 1'b1)) + ((pattern_els_p >> 39) & 1'b1)) + ((pattern_els_p >> 40) & 1'b1)) + ((pattern_els_p >> 41) & 1'b1)) + ((pattern_els_p >> 42) & 1'b1)) + ((pattern_els_p >> 43) & 1'b1)) + ((pattern_els_p >> 44) & 1'b1)) + ((pattern_els_p >> 45) & 1'b1)) + ((pattern_els_p >> 46) & 1'b1)) + ((pattern_els_p >> 47) & 1'b1)) + ((pattern_els_p >> 48) & 1'b1)) + ((pattern_els_p >> 49) & 1'b1)) + ((pattern_els_p >> 50) & 1'b1)) + ((pattern_els_p >> 51) & 1'b1)) + ((pattern_els_p >> 52) & 1'b1)) + ((pattern_els_p >> 53) & 1'b1)) + ((pattern_els_p >> 54) & 1'b1)) + ((pattern_els_p >> 55) & 1'b1)) + ((pattern_els_p >> 56) & 1'b1)) + ((pattern_els_p >> 57) & 1'b1)) + ((pattern_els_p >> 58) & 1'b1)) + ((pattern_els_p >> 59) & 1'b1)) + ((pattern_els_p >> 60) & 1'b1)) + ((pattern_els_p >> 61) & 1'b1)) + ((pattern_els_p >> 62) & 1'b1)) + ((pattern_els_p >> 63) & 1'b1));
	parameter unconnected_val_p = 1'sbz;
	input [width_lp - 1:0] i;
	output wire [31:0] o;
	genvar j;
	generate
		if (pattern_els_p[0]) begin : genblk1
			assign o[0] = i[0];
		end
		else begin : genblk1
			assign o[0] = unconnected_val_p;
		end
		for (j = 1; j < 32; j = j + 1) begin : rof
			if (pattern_els_p[j]) begin : genblk1
				assign o[j] = i[((j * 1) < 65 ? 1'b0 : 'x) + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((pattern_els_p[j - 1:0] >> 0) & 1'b1) + ((pattern_els_p[j - 1:0] >> 1) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 2) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 3) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 4) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 5) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 6) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 7) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 8) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 9) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 10) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 11) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 12) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 13) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 14) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 15) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 16) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 17) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 18) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 19) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 20) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 21) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 22) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 23) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 24) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 25) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 26) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 27) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 28) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 29) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 30) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 31) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 32) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 33) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 34) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 35) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 36) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 37) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 38) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 39) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 40) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 41) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 42) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 43) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 44) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 45) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 46) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 47) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 48) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 49) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 50) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 51) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 52) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 53) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 54) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 55) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 56) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 57) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 58) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 59) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 60) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 61) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 62) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 63) & 1'b1))];
			end
			else begin : genblk1
				assign o[j] = unconnected_val_p;
			end
		end
	endgenerate
endmodule
module bsg_unconcentrate_static__abstract;
	
endmodule
module bsg_mux_one_hot (
	data_i,
	sel_one_hot_i,
	data_o
);
	parameter width_p = 0;
	parameter signed [31:0] els_p = 1;
	parameter signed [31:0] harden_p = 1;
	input [(els_p * width_p) - 1:0] data_i;
	input [els_p - 1:0] sel_one_hot_i;
	output wire [width_p - 1:0] data_o;
	wire [(els_p * width_p) - 1:0] data_masked;
	genvar i;
	genvar j;
	generate
		for (i = 0; i < els_p; i = i + 1) begin : mask
			assign data_masked[i * width_p+:width_p] = data_i[i * width_p+:width_p] & {width_p {sel_one_hot_i[i]}};
		end
		for (i = 0; i < width_p; i = i + 1) begin : reduce
			wire [els_p - 1:0] gather;
			for (j = 0; j < els_p; j = j + 1) begin : reduce2
				assign gather[j] = data_masked[(j * width_p) + i];
			end
			assign data_o[i] = |gather;
		end
		if (els_p == 0) begin : zero
			assign data_o = 1'sb0;
		end
	endgenerate
endmodule
module bsg_mux_one_hot__abstract;
	
endmodule
module bsg_arb_round_robin_composable (
	clk_i,
	reset_i,
	reqs_i,
	grants_o,
	thermocode_r_i,
	thermocode_n_o
);
	parameter width_p = 0;
	localparam thermo_width_m1_lp = (width_p < 2 ? 0 : width_p - 2);
	input clk_i;
	input reset_i;
	input [width_p - 1:0] reqs_i;
	output wire [width_p - 1:0] grants_o;
	input [thermo_width_m1_lp:0] thermocode_r_i;
	output reg [thermo_width_m1_lp:0] thermocode_n_o;
	generate
		if (width_p == 1) begin : fi
			assign grants_o = reqs_i;
			wire [(thermo_width_m1_lp >= 0 ? thermo_width_m1_lp + 1 : 1 - thermo_width_m1_lp):1] sv2v_tmp_60521;
			assign sv2v_tmp_60521 = 1'b0;
			always @(*) thermocode_n_o = sv2v_tmp_60521;
		end
		else begin : fi2
			wire [(width_p * 2) - 1:0] scan_li = {1'b0, thermocode_r_i & reqs_i[width_p - 2:0], reqs_i};
			wire [(width_p * 2) - 1:0] scan_lo;
			bsg_scan #(
				.width_p(width_p * 2),
				.or_p(1)
			) scan(
				.i(scan_li),
				.o(scan_lo)
			);
			wire [(width_p * 2) - 1:0] edge_detect = ~(scan_lo >> 1) & scan_lo;
			assign grants_o = edge_detect[(width_p * 2) - 1-:width_p] | edge_detect[width_p - 1:0];
			always @(*)
				if (|scan_li[(width_p * 2) - 1-:width_p])
					thermocode_n_o = scan_lo[(width_p * 2) - 1-:width_p - 1];
				else
					thermocode_n_o = scan_lo[width_p - 1:1];
		end
	endgenerate
endmodule
module bsg_arb_round_robin_composable__abstract;
	
endmodule
module bsg_arb_round_robin (
	clk_i,
	reset_i,
	reqs_i,
	grants_o,
	yumi_i
);
	parameter width_p = 0;
	input clk_i;
	input reset_i;
	input [width_p - 1:0] reqs_i;
	output wire [width_p - 1:0] grants_o;
	input yumi_i;
	generate
		if (width_p == 1) begin : fi
			assign grants_o = reqs_i;
		end
		else begin : fi2
			reg [width_p - 2:0] thermocode_r;
			wire [width_p - 2:0] thermocode_n;
			always @(posedge clk_i)
				if (reset_i)
					thermocode_r <= 1'sb0;
				else if (yumi_i)
					thermocode_r <= thermocode_n;
			bsg_arb_round_robin_composable #(.width_p(width_p)) barrc(
				.clk_i(clk_i),
				.reset_i(reset_i),
				.reqs_i(reqs_i),
				.grants_o(grants_o),
				.thermocode_r_i(thermocode_r),
				.thermocode_n_o(thermocode_n)
			);
		end
	endgenerate
endmodule
module bsg_arb_round_robin_two_level (
	clk_i,
	reset_i,
	reqs_i,
	grants_o,
	granted_high_o,
	yumi_i
);
	parameter width_p = 0;
	input clk_i;
	input reset_i;
	input [(2 * width_p) - 1:0] reqs_i;
	output wire [width_p - 1:0] grants_o;
	output wire granted_high_o;
	input yumi_i;
	wire [width_p - 1:0] grants_low_lo;
	wire [width_p - 1:0] grants_high_lo;
	wire granted_low_lo;
	bsg_arb_round_robin #(.width_p(width_p)) low(
		.clk_i(clk_i),
		.reset_i(reset_i),
		.reqs_i(reqs_i[width_p+:width_p]),
		.grants_o(grants_low_lo),
		.yumi_i(granted_low_lo & yumi_i)
	);
	bsg_arb_round_robin #(.width_p(width_p)) hi(
		.clk_i(clk_i),
		.reset_i(reset_i),
		.reqs_i(reqs_i[0+:width_p]),
		.grants_o(grants_high_lo),
		.yumi_i(granted_high_o & yumi_i)
	);
	assign granted_high_o = |reqs_i[0+:width_p];
	assign granted_low_lo = |reqs_i[width_p+:width_p] & ~granted_high_o;
	assign grants_o = (granted_high_o ? grants_high_lo : grants_low_lo);
endmodule
module bsg_arb_round_robin__abstract;
	
endmodule
module bsg_arb_round_robin_two_level__abstract;
	
endmodule
module bsg_concentrate_static (
	i,
	o
);
	parameter pattern_els_p = 0;
	parameter width_lp = 32;
	parameter set_els_lp = 1'b0 + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((pattern_els_p >> 0) & 1'b1) + ((pattern_els_p >> 1) & 1'b1)) + ((pattern_els_p >> 2) & 1'b1)) + ((pattern_els_p >> 3) & 1'b1)) + ((pattern_els_p >> 4) & 1'b1)) + ((pattern_els_p >> 5) & 1'b1)) + ((pattern_els_p >> 6) & 1'b1)) + ((pattern_els_p >> 7) & 1'b1)) + ((pattern_els_p >> 8) & 1'b1)) + ((pattern_els_p >> 9) & 1'b1)) + ((pattern_els_p >> 10) & 1'b1)) + ((pattern_els_p >> 11) & 1'b1)) + ((pattern_els_p >> 12) & 1'b1)) + ((pattern_els_p >> 13) & 1'b1)) + ((pattern_els_p >> 14) & 1'b1)) + ((pattern_els_p >> 15) & 1'b1)) + ((pattern_els_p >> 16) & 1'b1)) + ((pattern_els_p >> 17) & 1'b1)) + ((pattern_els_p >> 18) & 1'b1)) + ((pattern_els_p >> 19) & 1'b1)) + ((pattern_els_p >> 20) & 1'b1)) + ((pattern_els_p >> 21) & 1'b1)) + ((pattern_els_p >> 22) & 1'b1)) + ((pattern_els_p >> 23) & 1'b1)) + ((pattern_els_p >> 24) & 1'b1)) + ((pattern_els_p >> 25) & 1'b1)) + ((pattern_els_p >> 26) & 1'b1)) + ((pattern_els_p >> 27) & 1'b1)) + ((pattern_els_p >> 28) & 1'b1)) + ((pattern_els_p >> 29) & 1'b1)) + ((pattern_els_p >> 30) & 1'b1)) + ((pattern_els_p >> 31) & 1'b1)) + ((pattern_els_p >> 32) & 1'b1)) + ((pattern_els_p >> 33) & 1'b1)) + ((pattern_els_p >> 34) & 1'b1)) + ((pattern_els_p >> 35) & 1'b1)) + ((pattern_els_p >> 36) & 1'b1)) + ((pattern_els_p >> 37) & 1'b1)) + ((pattern_els_p >> 38) & 1'b1)) + ((pattern_els_p >> 39) & 1'b1)) + ((pattern_els_p >> 40) & 1'b1)) + ((pattern_els_p >> 41) & 1'b1)) + ((pattern_els_p >> 42) & 1'b1)) + ((pattern_els_p >> 43) & 1'b1)) + ((pattern_els_p >> 44) & 1'b1)) + ((pattern_els_p >> 45) & 1'b1)) + ((pattern_els_p >> 46) & 1'b1)) + ((pattern_els_p >> 47) & 1'b1)) + ((pattern_els_p >> 48) & 1'b1)) + ((pattern_els_p >> 49) & 1'b1)) + ((pattern_els_p >> 50) & 1'b1)) + ((pattern_els_p >> 51) & 1'b1)) + ((pattern_els_p >> 52) & 1'b1)) + ((pattern_els_p >> 53) & 1'b1)) + ((pattern_els_p >> 54) & 1'b1)) + ((pattern_els_p >> 55) & 1'b1)) + ((pattern_els_p >> 56) & 1'b1)) + ((pattern_els_p >> 57) & 1'b1)) + ((pattern_els_p >> 58) & 1'b1)) + ((pattern_els_p >> 59) & 1'b1)) + ((pattern_els_p >> 60) & 1'b1)) + ((pattern_els_p >> 61) & 1'b1)) + ((pattern_els_p >> 62) & 1'b1)) + ((pattern_els_p >> 63) & 1'b1));
	input [width_lp - 1:0] i;
	output wire [set_els_lp - 1:0] o;
	genvar j;
	generate
		if (pattern_els_p[0]) begin : genblk1
			assign o[0] = i[0];
		end
		for (j = 1; j < width_lp; j = j + 1) begin : rof
			if (pattern_els_p[j]) begin : genblk1
				assign o[((j * 1) < 65 ? 1'b0 : {j {1'sbx}}) + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((pattern_els_p[j - 1:0] >> 0) & 1'b1) + ((pattern_els_p[j - 1:0] >> 1) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 2) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 3) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 4) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 5) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 6) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 7) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 8) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 9) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 10) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 11) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 12) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 13) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 14) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 15) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 16) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 17) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 18) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 19) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 20) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 21) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 22) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 23) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 24) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 25) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 26) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 27) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 28) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 29) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 30) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 31) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 32) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 33) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 34) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 35) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 36) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 37) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 38) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 39) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 40) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 41) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 42) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 43) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 44) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 45) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 46) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 47) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 48) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 49) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 50) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 51) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 52) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 53) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 54) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 55) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 56) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 57) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 58) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 59) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 60) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 61) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 62) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 63) & 1'b1))] = i[j];
			end
		end
	endgenerate
endmodule
module bsg_concentrate_static__abstract;
	
endmodule
module bsg_array_concentrate_static (
	i,
	o
);
	parameter pattern_els_p = 0;
	parameter width_p = 0;
	parameter dense_els_lp = 32;
	parameter sparse_els_lp = 1'b0 + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((pattern_els_p >> 0) & 1'b1) + ((pattern_els_p >> 1) & 1'b1)) + ((pattern_els_p >> 2) & 1'b1)) + ((pattern_els_p >> 3) & 1'b1)) + ((pattern_els_p >> 4) & 1'b1)) + ((pattern_els_p >> 5) & 1'b1)) + ((pattern_els_p >> 6) & 1'b1)) + ((pattern_els_p >> 7) & 1'b1)) + ((pattern_els_p >> 8) & 1'b1)) + ((pattern_els_p >> 9) & 1'b1)) + ((pattern_els_p >> 10) & 1'b1)) + ((pattern_els_p >> 11) & 1'b1)) + ((pattern_els_p >> 12) & 1'b1)) + ((pattern_els_p >> 13) & 1'b1)) + ((pattern_els_p >> 14) & 1'b1)) + ((pattern_els_p >> 15) & 1'b1)) + ((pattern_els_p >> 16) & 1'b1)) + ((pattern_els_p >> 17) & 1'b1)) + ((pattern_els_p >> 18) & 1'b1)) + ((pattern_els_p >> 19) & 1'b1)) + ((pattern_els_p >> 20) & 1'b1)) + ((pattern_els_p >> 21) & 1'b1)) + ((pattern_els_p >> 22) & 1'b1)) + ((pattern_els_p >> 23) & 1'b1)) + ((pattern_els_p >> 24) & 1'b1)) + ((pattern_els_p >> 25) & 1'b1)) + ((pattern_els_p >> 26) & 1'b1)) + ((pattern_els_p >> 27) & 1'b1)) + ((pattern_els_p >> 28) & 1'b1)) + ((pattern_els_p >> 29) & 1'b1)) + ((pattern_els_p >> 30) & 1'b1)) + ((pattern_els_p >> 31) & 1'b1)) + ((pattern_els_p >> 32) & 1'b1)) + ((pattern_els_p >> 33) & 1'b1)) + ((pattern_els_p >> 34) & 1'b1)) + ((pattern_els_p >> 35) & 1'b1)) + ((pattern_els_p >> 36) & 1'b1)) + ((pattern_els_p >> 37) & 1'b1)) + ((pattern_els_p >> 38) & 1'b1)) + ((pattern_els_p >> 39) & 1'b1)) + ((pattern_els_p >> 40) & 1'b1)) + ((pattern_els_p >> 41) & 1'b1)) + ((pattern_els_p >> 42) & 1'b1)) + ((pattern_els_p >> 43) & 1'b1)) + ((pattern_els_p >> 44) & 1'b1)) + ((pattern_els_p >> 45) & 1'b1)) + ((pattern_els_p >> 46) & 1'b1)) + ((pattern_els_p >> 47) & 1'b1)) + ((pattern_els_p >> 48) & 1'b1)) + ((pattern_els_p >> 49) & 1'b1)) + ((pattern_els_p >> 50) & 1'b1)) + ((pattern_els_p >> 51) & 1'b1)) + ((pattern_els_p >> 52) & 1'b1)) + ((pattern_els_p >> 53) & 1'b1)) + ((pattern_els_p >> 54) & 1'b1)) + ((pattern_els_p >> 55) & 1'b1)) + ((pattern_els_p >> 56) & 1'b1)) + ((pattern_els_p >> 57) & 1'b1)) + ((pattern_els_p >> 58) & 1'b1)) + ((pattern_els_p >> 59) & 1'b1)) + ((pattern_els_p >> 60) & 1'b1)) + ((pattern_els_p >> 61) & 1'b1)) + ((pattern_els_p >> 62) & 1'b1)) + ((pattern_els_p >> 63) & 1'b1));
	input [(dense_els_lp * width_p) - 1:0] i;
	output wire [(sparse_els_lp * width_p) - 1:0] o;
	genvar j;
	generate
		if (pattern_els_p[0]) begin : genblk1
			assign o[0+:width_p] = i[0+:width_p];
		end
		for (j = 1; j < dense_els_lp; j = j + 1) begin : rof
			if (pattern_els_p[j]) begin : genblk1
				assign o[(((j * 1) < 65 ? 1'b0 : {j {1'sbx}}) + (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((pattern_els_p[j - 1:0] >> 0) & 1'b1) + ((pattern_els_p[j - 1:0] >> 1) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 2) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 3) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 4) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 5) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 6) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 7) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 8) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 9) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 10) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 11) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 12) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 13) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 14) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 15) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 16) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 17) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 18) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 19) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 20) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 21) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 22) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 23) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 24) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 25) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 26) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 27) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 28) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 29) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 30) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 31) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 32) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 33) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 34) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 35) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 36) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 37) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 38) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 39) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 40) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 41) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 42) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 43) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 44) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 45) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 46) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 47) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 48) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 49) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 50) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 51) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 52) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 53) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 54) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 55) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 56) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 57) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 58) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 59) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 60) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 61) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 62) & 1'b1)) + ((pattern_els_p[j - 1:0] >> 63) & 1'b1))) * width_p+:width_p] = i[j * width_p+:width_p];
			end
		end
	endgenerate
endmodule
module bsg_array_cocentrate_static__abstract;
	
endmodule
module bsg_mesh_router_decoder_dor (
	clk_i,
	reset_i,
	x_dirs_i,
	y_dirs_i,
	my_x_i,
	my_y_i,
	entropy_val,
	router_id_val,
	req_o
);
	parameter x_cord_width_p = 0;
	parameter y_cord_width_p = 0;
	parameter dims_p = 2;
	parameter dirs_lp = (2 * dims_p) + 1;
	parameter ruche_factor_X_p = 0;
	parameter ruche_factor_Y_p = 0;
	parameter XY_order_p = 1;
	parameter depopulated_p = 1;
	parameter from_p = {dirs_lp {1'b0}};
	parameter debug_p = 1;
	input clk_i;
	input reset_i;
	input [x_cord_width_p - 1:0] x_dirs_i;
	input [y_cord_width_p - 1:0] y_dirs_i;
	input [x_cord_width_p - 1:0] my_x_i;
	input [y_cord_width_p - 1:0] my_y_i;
	input [2:0] entropy_val;
	input [5:0] router_id_val;
	output wire [dirs_lp - 1:0] req_o;
	initial begin
		if (ruche_factor_X_p > 0)
			;
		if (ruche_factor_Y_p > 0)
			;
	end
	wire x_eq = x_dirs_i == my_x_i;
	wire y_eq = y_dirs_i == my_y_i;
	wire x_gt = x_dirs_i > my_x_i;
	wire y_gt = y_dirs_i > my_y_i;
	wire x_lt = ~x_gt & ~x_eq;
	wire y_lt = ~y_gt & ~y_eq;
	wire [dirs_lp - 1:0] req;
	assign req_o = req;
	assign req[3'd0] = x_eq & y_eq;
	localparam signed [31:0] W = 8;
	localparam [7:0] HASH_CONST = 8'hb9;
	wire [5:0] z_pre = {router_id_val[5:3], entropy_val[2:0] ^ router_id_val[2:0]};
	wire [7:0] z_mix = z_pre * HASH_CONST;
	wire decision_bit = z_mix[7];
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	assign req[sv2v_cast_3((3'd0 + 1) + 2)] = (x_eq ? y_lt : (y_eq ? 1'b0 : (x_lt ? 1'b0 : (decision_bit ? y_lt : 1'b0))));
	assign req[sv2v_cast_3((3'd0 + 1) + 3)] = (x_eq ? y_gt : (y_eq ? 1'b0 : (x_lt ? 1'b0 : (decision_bit ? y_gt : 1'b0))));
	assign req[W] = (x_eq ? 1'b0 : (y_eq ? x_lt : (x_lt ? 1'b1 : (decision_bit ? 1'b0 : x_lt))));
	assign req[sv2v_cast_3((3'd0 + 1) + 1)] = (x_eq ? 1'b0 : (y_eq ? x_gt : (x_lt ? 1'b0 : (decision_bit ? 1'b1 : x_gt))));
	generate
		if (debug_p) begin : genblk1
			always @(negedge clk_i)
				if (~reset_i)
					;
		end
		else begin : genblk1
			wire unused0 = clk_i;
			wire unused1 = reset_i;
		end
	endgenerate
endmodule
module bsg_mesh_router_decoder_dor__abstract;
	
endmodule
module bsg_transpose (
	i,
	o
);
	parameter width_p = 0;
	parameter els_p = 0;
	parameter type_width_p = 1;
	input [((els_p * width_p) * type_width_p) - 1:0] i;
	output wire [((width_p * els_p) * type_width_p) - 1:0] o;
	genvar x;
	genvar y;
	generate
		for (x = 0; x < els_p; x = x + 1) begin : rof
			for (y = 0; y < width_p; y = y + 1) begin : rof2
				assign o[((y * els_p) + x) * type_width_p+:type_width_p] = i[((x * width_p) + y) * type_width_p+:type_width_p];
			end
		end
	endgenerate
endmodule
module bsg_transpose__abstract;
	
endmodule
module bsg_fifo_1r1w_small_unhardened (
	clk_i,
	reset_i,
	v_i,
	ready_param_o,
	data_i,
	v_o,
	data_o,
	yumi_i
);
	parameter width_p = 0;
	parameter els_p = 0;
	parameter ready_THEN_valid_p = 0;
	input clk_i;
	input reset_i;
	input v_i;
	output wire ready_param_o;
	input [width_p - 1:0] data_i;
	output wire v_o;
	output wire [width_p - 1:0] data_o;
	input yumi_i;
	wire deque = yumi_i;
	wire v_o_tmp;
	assign v_o = v_o_tmp;
	wire enque;
	wire ready_param_lo;
	generate
		if (ready_THEN_valid_p) begin : rtv
			assign enque = v_i;
		end
		else begin : rav
			assign enque = v_i & ready_param_lo;
		end
	endgenerate
	localparam ptr_width_lp = ((els_p == 1) || (els_p == 0) ? 1 : $clog2(els_p));
	wire [ptr_width_lp - 1:0] rptr_r;
	wire [ptr_width_lp - 1:0] wptr_r;
	wire full;
	wire empty;
	bsg_fifo_tracker #(.els_p(els_p)) ft(
		.clk_i(clk_i),
		.reset_i(reset_i),
		.enq_i(enque),
		.deq_i(deque),
		.wptr_r_o(wptr_r),
		.rptr_r_o(rptr_r),
		.rptr_n_o(),
		.full_o(full),
		.empty_o(empty)
	);
	bsg_mem_1r1w #(
		.width_p(width_p),
		.els_p(els_p),
		.read_write_same_addr_p(0)
	) mem_1r1w(
		.w_clk_i(clk_i),
		.w_reset_i(reset_i),
		.w_v_i(enque),
		.w_addr_i(wptr_r),
		.w_data_i(data_i),
		.r_v_i(v_o_tmp),
		.r_addr_i(rptr_r),
		.r_data_o(data_o)
	);
	assign ready_param_lo = ~full;
	assign ready_param_o = ready_param_lo;
	assign v_o_tmp = ~empty;
	always @(posedge clk_i) begin
		if (((ready_THEN_valid_p & full) & v_i) & ~reset_i)
			$display("%m error: enque full fifo at time %t", $time);
		if ((empty & yumi_i) & ~reset_i)
			$display("%m error: deque empty fifo at time %t", $time);
	end
endmodule
module bsg_fifo_1r1w_small_unhardened__abstract;
	
endmodule
module bsg_mem_1r1w (
	w_clk_i,
	w_reset_i,
	w_v_i,
	w_addr_i,
	w_data_i,
	r_v_i,
	r_addr_i,
	r_data_o
);
	parameter width_p = 0;
	parameter els_p = 0;
	parameter read_write_same_addr_p = 0;
	parameter addr_width_lp = ((els_p == 1) || (els_p == 0) ? 1 : $clog2(els_p));
	parameter harden_p = 0;
	input w_clk_i;
	input w_reset_i;
	input w_v_i;
	input [addr_width_lp - 1:0] w_addr_i;
	input [(width_p < 1 ? 0 : width_p - 1):0] w_data_i;
	input r_v_i;
	input [addr_width_lp - 1:0] r_addr_i;
	output wire [(width_p < 1 ? 0 : width_p - 1):0] r_data_o;
	bsg_mem_1r1w_synth #(
		.width_p(width_p),
		.els_p(els_p),
		.read_write_same_addr_p(read_write_same_addr_p)
	) synth(
		.w_clk_i(w_clk_i),
		.w_reset_i(w_reset_i),
		.w_v_i(w_v_i),
		.w_addr_i(w_addr_i),
		.w_data_i(w_data_i),
		.r_v_i(r_v_i),
		.r_addr_i(r_addr_i),
		.r_data_o(r_data_o)
	);
	initial if ((width_p * els_p) > 256)
		$display("## %L: instantiating width_p=%d, els_p=%d, read_write_same_addr_p=%d, harden_p=%d (%m)", width_p, els_p, read_write_same_addr_p, harden_p);
	always @(negedge w_clk_i)
		if (w_v_i === 1'b1)
			;
endmodule
module bsg_mem_1r1w__abstract;
	
endmodule
module bsg_fifo_tracker (
	clk_i,
	reset_i,
	enq_i,
	deq_i,
	wptr_r_o,
	rptr_r_o,
	rptr_n_o,
	full_o,
	empty_o
);
	parameter els_p = 0;
	parameter ptr_width_lp = ((els_p == 1) || (els_p == 0) ? 1 : $clog2(els_p));
	input clk_i;
	input reset_i;
	input enq_i;
	input deq_i;
	output wire [ptr_width_lp - 1:0] wptr_r_o;
	output wire [ptr_width_lp - 1:0] rptr_r_o;
	output wire [ptr_width_lp - 1:0] rptr_n_o;
	output wire full_o;
	output wire empty_o;
	wire [ptr_width_lp - 1:0] rptr_r;
	wire [ptr_width_lp - 1:0] rptr_n;
	wire [ptr_width_lp - 1:0] wptr_r;
	assign wptr_r_o = wptr_r;
	assign rptr_r_o = rptr_r;
	assign rptr_n_o = rptr_n;
	reg enq_r;
	reg deq_r;
	wire empty;
	wire full;
	wire equal_ptrs;
	bsg_circular_ptr #(
		.slots_p(els_p),
		.max_add_p(1)
	) rptr(
		.clk(clk_i),
		.reset_i(reset_i),
		.add_i(deq_i),
		.o(rptr_r),
		.n_o(rptr_n)
	);
	bsg_circular_ptr #(
		.slots_p(els_p),
		.max_add_p(1)
	) wptr(
		.clk(clk_i),
		.reset_i(reset_i),
		.add_i(enq_i),
		.o(wptr_r),
		.n_o()
	);
	always @(posedge clk_i)
		if (reset_i) begin
			enq_r <= 1'b0;
			deq_r <= 1'b1;
		end
		else if (enq_i | deq_i) begin
			enq_r <= enq_i;
			deq_r <= deq_i;
		end
	assign equal_ptrs = rptr_r == wptr_r;
	assign empty = equal_ptrs & deq_r;
	assign full = equal_ptrs & enq_r;
	assign full_o = full;
	assign empty_o = empty;
endmodule
module bsg_fifo_tracker__abstract;
	
endmodule
module bsg_scan (
	i,
	o
);
	parameter width_p = 0;
	parameter xor_p = 0;
	parameter and_p = 0;
	parameter or_p = 0;
	parameter lo_to_hi_p = 0;
	parameter debug_p = 0;
	input [width_p - 1:0] i;
	output wire [width_p - 1:0] o;
	genvar j;
	wire [($clog2(width_p) >= 0 ? (($clog2(width_p) + 1) * width_p) - 1 : ((1 - $clog2(width_p)) * width_p) + (($clog2(width_p) * width_p) - 1)):($clog2(width_p) >= 0 ? 0 : $clog2(width_p) * width_p)] t;
	generate
		if (debug_p) begin : genblk1
			always @(o) begin
				#(1) begin : sv2v_autoblock_1
					integer k;
					for (k = 0; k <= $clog2(width_p); k = k + 1)
						$display("%b", t[($clog2(width_p) >= 0 ? k : $clog2(width_p) - k) * width_p+:width_p]);
				end
				$display("i=%b, o=%b", i, o);
			end
		end
		if (lo_to_hi_p) begin : genblk2
			function automatic [width_p - 1:0] _sv2v_strm_F2A76;
				input reg [(0 + width_p) - 1:0] inp;
				reg [(0 + width_p) - 1:0] _sv2v_strm_55E18_inp;
				reg [(0 + width_p) - 1:0] _sv2v_strm_55E18_out;
				integer _sv2v_strm_55E18_idx;
				begin
					_sv2v_strm_55E18_inp = {inp};
					for (_sv2v_strm_55E18_idx = 0; _sv2v_strm_55E18_idx <= ((0 + width_p) - 1); _sv2v_strm_55E18_idx = _sv2v_strm_55E18_idx + 1)
						_sv2v_strm_55E18_out[((0 + width_p) - 1) - _sv2v_strm_55E18_idx-:1] = _sv2v_strm_55E18_inp[_sv2v_strm_55E18_idx+:1];
					_sv2v_strm_F2A76 = ((0 + width_p) <= width_p ? _sv2v_strm_55E18_out << (width_p - (0 + width_p)) : _sv2v_strm_55E18_out >> ((0 + width_p) - width_p));
				end
			endfunction
			assign t[($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p+:width_p] = _sv2v_strm_F2A76({i});
		end
		else begin : genblk2
			assign t[($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p+:width_p] = i;
		end
	endgenerate
	function automatic [width_p - 1:0] sv2v_cast_4B3A8;
		input reg [width_p - 1:0] inp;
		sv2v_cast_4B3A8 = inp;
	endfunction
	generate
		if ((width_p == 4) & and_p) begin : scand4
			assign t[($clog2(width_p) >= 0 ? $clog2(width_p) : $clog2(width_p) - $clog2(width_p)) * width_p+:width_p] = {t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 3], &t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 3-:2], &t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 3-:3], &t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 3-:4]};
		end
		else if ((width_p == 3) & and_p) begin : scand3
			assign t[($clog2(width_p) >= 0 ? $clog2(width_p) : $clog2(width_p) - $clog2(width_p)) * width_p+:width_p] = {t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 2], &t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 2-:2], &t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 2-:3]};
		end
		else if ((width_p == 2) & and_p) begin : scand3
			assign t[($clog2(width_p) >= 0 ? $clog2(width_p) : $clog2(width_p) - $clog2(width_p)) * width_p+:width_p] = {t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 1], &t[(($clog2(width_p) >= 0 ? 0 : $clog2(width_p)) * width_p) + 1-:2]};
		end
		else begin : scanN
			for (j = 0; j < $clog2(width_p); j = j + 1) begin : row
				wire [width_p - 1:0] fill;
				wire [width_p - 1:0] shifted = sv2v_cast_4B3A8({fill, t[($clog2(width_p) >= 0 ? j : $clog2(width_p) - j) * width_p+:width_p]} >> (1 << j));
				if (xor_p) begin : genblk1
					assign fill = {width_p {1'b0}};
					assign t[($clog2(width_p) >= 0 ? j + 1 : $clog2(width_p) - (j + 1)) * width_p+:width_p] = t[($clog2(width_p) >= 0 ? j : $clog2(width_p) - j) * width_p+:width_p] ^ shifted;
				end
				else if (and_p) begin : genblk1
					assign fill = {width_p {1'b1}};
					assign t[($clog2(width_p) >= 0 ? j + 1 : $clog2(width_p) - (j + 1)) * width_p+:width_p] = t[($clog2(width_p) >= 0 ? j : $clog2(width_p) - j) * width_p+:width_p] & shifted;
				end
				else if (or_p) begin : genblk1
					assign fill = {width_p {1'b0}};
					assign t[($clog2(width_p) >= 0 ? j + 1 : $clog2(width_p) - (j + 1)) * width_p+:width_p] = t[($clog2(width_p) >= 0 ? j : $clog2(width_p) - j) * width_p+:width_p] | shifted;
				end
			end
		end
		if (lo_to_hi_p) begin : genblk4
			for (j = 0; j < width_p; j = j + 1) begin : genblk1
				assign o[j] = t[(($clog2(width_p) >= 0 ? $clog2(width_p) : $clog2(width_p) - $clog2(width_p)) * width_p) + ((width_p - 1) - j)];
			end
		end
		else begin : genblk4
			assign o = t[($clog2(width_p) >= 0 ? $clog2(width_p) : $clog2(width_p) - $clog2(width_p)) * width_p+:width_p];
		end
	endgenerate
endmodule
module bsg_scan__abstract;
	
endmodule
module bsg_circular_ptr (
	clk,
	reset_i,
	add_i,
	o,
	n_o
);
	parameter slots_p = 0;
	parameter max_add_p = 0;
	parameter const_incr_p = 1'b0;
	parameter ptr_width_lp = ((slots_p == 1) || (slots_p == 0) ? 1 : $clog2(slots_p));
	input clk;
	input reset_i;
	input [$clog2(max_add_p + 1) - 1:0] add_i;
	output wire [ptr_width_lp - 1:0] o;
	output wire [ptr_width_lp - 1:0] n_o;
	reg [ptr_width_lp - 1:0] ptr_r;
	wire [ptr_width_lp - 1:0] ptr_n;
	wire [ptr_width_lp - 1:0] ptr_nowrap;
	wire [ptr_width_lp:0] ptr_wrap;
	assign o = ptr_r;
	assign n_o = ptr_n;
	always @(posedge clk)
		if (reset_i)
			ptr_r <= 1'sb0;
		else
			ptr_r <= ptr_n;
	function automatic [((ptr_width_lp + 0) >= 0 ? ptr_width_lp + 1 : 1 - (ptr_width_lp + 0)) - 1:0] sv2v_cast_CA6F4;
		input reg [((ptr_width_lp + 0) >= 0 ? ptr_width_lp + 1 : 1 - (ptr_width_lp + 0)) - 1:0] inp;
		sv2v_cast_CA6F4 = inp;
	endfunction
	function automatic [ptr_width_lp - 1:0] sv2v_cast_716B6;
		input reg [ptr_width_lp - 1:0] inp;
		sv2v_cast_716B6 = inp;
	endfunction
	generate
		if (slots_p == 1) begin : genblk1
			assign ptr_n = 1'b0;
			wire ignore = |add_i;
		end
		else if ((1 << $clog2(slots_p)) == slots_p) begin : genblk1
			if ((max_add_p == 1) || const_incr_p) begin : genblk1
				wire [ptr_width_lp - 1:0] ptr_r_p1 = ptr_r + max_add_p[ptr_width_lp - 1:0];
				assign ptr_n = (add_i ? ptr_r_p1 : ptr_r);
			end
			else begin : genblk1
				assign ptr_n = sv2v_cast_716B6(ptr_r + add_i);
			end
		end
		else begin : notpow2
			assign ptr_wrap = sv2v_cast_CA6F4(({1'b0, ptr_r} - slots_p) + add_i);
			assign ptr_nowrap = ptr_r + add_i;
			assign ptr_n = (~ptr_wrap[ptr_width_lp] ? ptr_wrap[0+:ptr_width_lp] : ptr_nowrap);
			always @(*)
				;
		end
	endgenerate
endmodule
module bsg_circular_ptr__abstract;
	
endmodule
module bsg_mem_1r1w_synth (
	w_clk_i,
	w_reset_i,
	w_v_i,
	w_addr_i,
	w_data_i,
	r_v_i,
	r_addr_i,
	r_data_o
);
	parameter width_p = 0;
	parameter els_p = 0;
	parameter read_write_same_addr_p = 0;
	parameter addr_width_lp = ((els_p == 1) || (els_p == 0) ? 1 : $clog2(els_p));
	input w_clk_i;
	input w_reset_i;
	input w_v_i;
	input [addr_width_lp - 1:0] w_addr_i;
	input [(width_p < 1 ? 0 : width_p - 1):0] w_data_i;
	input r_v_i;
	input [addr_width_lp - 1:0] r_addr_i;
	output wire [(width_p < 1 ? 0 : width_p - 1):0] r_data_o;
	wire unused0 = w_reset_i;
	wire unused1 = r_v_i;
	generate
		if ((width_p == 0) || (els_p == 0)) begin : z
			wire unused2 = &{w_clk_i, w_addr_i, w_data_i, r_addr_i};
			assign r_data_o = 1'sb0;
		end
		else begin : nz
			reg [width_p - 1:0] mem [els_p - 1:0];
			wire [addr_width_lp - 1:0] r_addr_li = (els_p > 0 ? r_addr_i : {addr_width_lp {1'sb0}});
			wire [addr_width_lp - 1:0] w_addr_li = (els_p > 0 ? w_addr_i : {addr_width_lp {1'sb0}});
			assign r_data_o = mem[r_addr_li];
			always @(posedge w_clk_i)
				if (w_v_i)
					mem[w_addr_li] <= w_data_i;
		end
	endgenerate
endmodule
module bsg_mem_1r1w_synth__abstract;
	
endmodule
module bsg_two_fifo (
	clk_i,
	reset_i,
	ready_param_o,
	data_i,
	v_i,
	v_o,
	data_o,
	yumi_i
);
	parameter width_p = 0;
	parameter verbose_p = 0;
	parameter allow_enq_deq_on_full_p = 0;
	parameter ready_THEN_valid_p = allow_enq_deq_on_full_p;
	input clk_i;
	input reset_i;
	output wire ready_param_o;
	input [width_p - 1:0] data_i;
	input v_i;
	output wire v_o;
	output wire [width_p - 1:0] data_o;
	input yumi_i;
	wire deq_i = yumi_i;
	wire enq_i;
	reg head_r;
	reg tail_r;
	reg empty_r;
	reg full_r;
	bsg_mem_1r1w #(
		.width_p(width_p),
		.els_p(2),
		.read_write_same_addr_p(allow_enq_deq_on_full_p)
	) mem_1r1w(
		.w_clk_i(clk_i),
		.w_reset_i(reset_i),
		.w_v_i(enq_i),
		.w_addr_i(tail_r),
		.w_data_i(data_i),
		.r_v_i(~empty_r),
		.r_addr_i(head_r),
		.r_data_o(data_o)
	);
	assign v_o = ~empty_r;
	assign ready_param_o = ~full_r;
	generate
		if (ready_THEN_valid_p) begin : genblk1
			assign enq_i = v_i;
		end
		else begin : genblk1
			assign enq_i = v_i & ~full_r;
		end
	endgenerate
	always @(posedge clk_i)
		if (reset_i) begin
			tail_r <= 1'b0;
			head_r <= 1'b0;
			empty_r <= 1'b1;
			full_r <= 1'b0;
		end
		else begin
			if (enq_i)
				tail_r <= ~tail_r;
			if (deq_i)
				head_r <= ~head_r;
			empty_r <= (empty_r & ~enq_i) | ((~full_r & deq_i) & ~enq_i);
			if (allow_enq_deq_on_full_p)
				full_r <= ((~empty_r & enq_i) & ~deq_i) | (full_r & ~(deq_i ^ enq_i));
			else
				full_r <= ((~empty_r & enq_i) & ~deq_i) | (full_r & ~deq_i);
		end
	always @(posedge clk_i)
		if (~reset_i) begin
			if (allow_enq_deq_on_full_p)
				;
		end
	always @(posedge clk_i)
		if (verbose_p) begin
			if (enq_i)
				$display("### %m enq %x onto fifo", data_i);
			if (deq_i)
				$display("### %m deq %x from fifo", data_o);
		end
	wire [31:0] num_elements_debug = full_r + (empty_r == 0);
endmodule
module bsg_two_fifo__abstract;
	
endmodule
