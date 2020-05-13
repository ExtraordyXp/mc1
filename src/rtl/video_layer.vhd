----------------------------------------------------------------------------------------------------
-- Copyright (c) 2020 Marcus Geelnard
--
-- This software is provided 'as-is', without any express or implied warranty. In no event will the
-- authors be held liable for any damages arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose, including commercial
-- applications, and to alter it and redistribute it freely, subject to the following restrictions:
--
--  1. The origin of this software must not be misrepresented; you must not claim that you wrote
--     the original software. If you use this software in a product, an acknowledgment in the
--     product documentation would be appreciated but is not required.
--
--  2. Altered source versions must be plainly marked as such, and must not be misrepresented as
--     being the original software.
--
--  3. This notice may not be removed or altered from any source distribution.
----------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vid_types.all;

entity video_layer is
  generic(
    X_COORD_BITS : positive;
    Y_COORD_BITS : positive;
    VCP_START_ADDRESS : std_logic_vector(23 downto 0)
  );
  port(
    i_rst : in std_logic;
    i_clk : in std_logic;

    i_restart_frame : in std_logic;
    i_raster_x : in std_logic_vector(X_COORD_BITS-1 downto 0);
    i_raster_y : in std_logic_vector(Y_COORD_BITS-1 downto 0);

    o_read_en : out std_logic;
    o_read_adr : out std_logic_vector(23 downto 0);
    i_read_ack : in std_logic;
    i_read_dat : in std_logic_vector(31 downto 0);

    o_rmode : out std_logic_vector(23 downto 0);
    o_color : out std_logic_vector(31 downto 0)
  );
end video_layer;

architecture rtl of video_layer is
  signal s_vcpp_mem_read_en : std_logic;
  signal s_vcpp_mem_read_addr : std_logic_vector(23 downto 0);
  signal s_next_vcpp_mem_expect_ack : std_logic;
  signal s_vcpp_mem_expect_ack : std_logic;
  signal s_vcpp_mem_ack : std_logic;
  signal s_vcpp_reg_write_enable : std_logic;
  signal s_vcpp_pal_write_enable : std_logic;
  signal s_vcpp_write_addr : std_logic_vector(7 downto 0);
  signal s_vcpp_write_data : std_logic_vector(31 downto 0);

  signal s_regs : T_VID_REGS;

  signal s_pix_mem_read_en : std_logic;
  signal s_pix_mem_read_addr : std_logic_vector(23 downto 0);
  signal s_next_pix_mem_expect_ack : std_logic;
  signal s_pix_mem_expect_ack : std_logic;
  signal s_pix_mem_ack : std_logic;
  signal s_pix_pal_addr : std_logic_vector(7 downto 0);
  signal s_pix_pal_data : std_logic_vector(31 downto 0);
begin
  -- Instantiate the video control program processor.
  vcpp_1: entity work.vid_vcpp
    generic map (
      X_COORD_BITS => X_COORD_BITS,
      Y_COORD_BITS => Y_COORD_BITS,
      VCP_START_ADDRESS => VCP_START_ADDRESS
    )
    port map(
      i_rst => i_rst,
      i_clk => i_clk,
      i_restart_frame => i_restart_frame,
      i_raster_x => i_raster_x,
      i_raster_y => i_raster_y,
      o_mem_read_en => s_vcpp_mem_read_en,
      o_mem_read_addr => s_vcpp_mem_read_addr,
      i_mem_data => i_read_dat,
      i_mem_ack => s_vcpp_mem_ack,
      o_reg_write_enable => s_vcpp_reg_write_enable,
      o_pal_write_enable => s_vcpp_pal_write_enable,
      o_write_addr => s_vcpp_write_addr,
      o_write_data => s_vcpp_write_data
    );

  -- Instantiate the video control registers.
  vcr_1: entity work.vid_regs
    port map(
      i_rst => i_rst,
      i_clk => i_clk,
      i_restart_frame => i_restart_frame,
      i_write_enable => s_vcpp_reg_write_enable,
      i_write_addr => s_vcpp_write_addr(2 downto 0),
      i_write_data => s_vcpp_write_data(23 downto 0),
      o_regs => s_regs
    );

  -- Instantiate the video palette.
  palette_1: entity work.vid_palette
    port map(
      i_rst => i_rst,
      i_clk => i_clk,
      i_write_enable => s_vcpp_pal_write_enable,
      i_write_addr => s_vcpp_write_addr,
      i_write_data => s_vcpp_write_data,
      i_read_addr => s_pix_pal_addr,
      o_read_data => s_pix_pal_data
    );

  -- Instantiate the pixel pipeline.
  pixel_pipe_1: entity work.vid_pixel
    generic map (
      X_COORD_BITS => X_COORD_BITS,
      Y_COORD_BITS => Y_COORD_BITS
    )
    port map(
      i_rst => i_rst,
      i_clk => i_clk,
      i_raster_x => i_raster_x,
      i_raster_y => i_raster_y,
      o_mem_read_en => s_pix_mem_read_en,
      o_mem_read_addr => s_pix_mem_read_addr,
      i_mem_data => i_read_dat,
      i_mem_ack => s_pix_mem_ack,
      o_pal_addr => s_pix_pal_addr,
      i_pal_data => s_pix_pal_data,
      i_regs => s_regs,
      o_color => o_color
    );

  -- Output the render mode (used by the blending and dithering logic).
  o_rmode <= s_regs.RMODE;


  --------------------------------------------------------------------------------------------------
  -- VRAM read logic - only one entity may access VRAM during each clock cycle.
  --------------------------------------------------------------------------------------------------

  o_read_en <= s_pix_mem_read_en or s_vcpp_mem_read_en;

  -- Select the active read unit - The pixel pipe has priority over the VCPP.
  o_read_adr <= s_pix_mem_read_addr when s_pix_mem_read_en = '1' else
                s_vcpp_mem_read_addr when s_vcpp_mem_read_en = '1' else
                (others => '-');
  s_next_pix_mem_expect_ack <= s_pix_mem_read_en;
  s_next_vcpp_mem_expect_ack <= s_vcpp_mem_read_en and not s_pix_mem_read_en;

  -- Respond with an ack to the relevant unit (one cycle after).
  process(i_clk, i_rst)
  begin
    if i_rst = '1' then
      s_pix_mem_expect_ack <= '0';
      s_vcpp_mem_expect_ack <= '0';
    elsif rising_edge(i_clk) then
      s_pix_mem_expect_ack <= s_next_pix_mem_expect_ack;
      s_vcpp_mem_expect_ack <= s_next_vcpp_mem_expect_ack;
    end if;
  end process;
  s_pix_mem_ack <= s_pix_mem_expect_ack and i_read_ack;
  s_vcpp_mem_ack <= s_vcpp_mem_expect_ack and i_read_ack;
end rtl;