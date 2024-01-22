library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity top_level is
	port ( 	clock 			: in std_logic;
		button_1_IN		: in std_logic;
		button_2_IN		: in std_logic;
		enable_2v4_dual_supply	: out std_logic;
		enable_shunt		: out std_logic;
		enable_driver		: out std_logic;
		enable_source_selector	: out std_logic;
		driver_signal		: out std_logic;
		shunt_a0		: out std_logic;
		shunt_a1		: out std_logic;
		shunt_a2		: out std_logic;
		source_a4		: out std_logic;
		source_a5		: out std_logic;
		source_a6		: out std_logic;
		led0_r          : out std_logic;
		led0_g          : out std_logic;
		led0_b          : out std_logic;
		led             : out std_logic_vector(3 downto 0)  
	);
end top_level;


architecture structural of top_level is

constant CLK_FREQ : natural := 12;  -- [MHz]
constant FRES_1 : natural := 375; -- [kHz]
constant FRES_2 : natural := 2 * FRES_1; -- [kHz]
constant FSLOW : natural := 1000; -- [Hz]
constant TRES_1 : natural := 34; --((CLK_FREQ * 1000) / FRES_1) - 1;
constant TRES_2 : natural := 17; --((CLK_FREQ * 1000) / FRES_2) - 1;
constant TSLOW : natural := ((CLK_FREQ * 1000 * 1000) / FSLOW) - 1;
constant TSLOW_HALF : natural := (TSLOW + 1)/2;
constant SHUNT_DELAY : natural := 6; -- amount of cycles after an impulse before switching to shunt
constant T_FB_GND : natural := TRES_1 * 6; -- time after which to switch to GDN during feedback mode

signal 	button_1_TRIG, button_2_TRIG, button_1, button_2 : std_logic;
signal 	global_counter 		: natural range 0 to TSLOW := 0;
signal 	driving_state_vector 	: std_logic_vector(2 downto 0);
signal 	shunt_reg 		: natural range 1 to 8 := 1; -- there are 6 different shunt connections: S1-S8. S1 and S2 are not connected.
signal 	LED_rgb			: std_logic_vector(2 downto 0) := "000";
signal 	LEDs_yellow		: std_logic_vector(3 downto 0) := "0000";
signal 	shunt			: std_logic_vector(2 downto 0);
signal	source			: std_logic_vector(2 downto 0); 


signal driving_state 		: std_logic_vector(2 downto 0); 
-- STANDBY, SINGLE_PULSE, COUNTER_PULSE, FEEDBACK SINGLE PULSE, FEEDBACK COUNTERPULSE;

component button_debouncer is
	port (
		clock 		: in  std_logic;
		button_IN  	: in  std_logic;
		button_OUT 	: out std_logic;
		trigger		: out std_logic
	);
end component;

component LED_driver is
	port (
		clock 		: in  std_logic;
		driving_state  	: in  std_logic_vector(2 downto 0);
		shunt_number 	: in  natural range 0 to 8;
		LED_rgb		: out std_logic_vector(2 downto 0);
		LEDs_yellow 	: out std_logic_vector(3 downto 0)
	);
end component;

begin
	process(clock)
		begin
			if (rising_edge(clock)) then
				case driving_state is
					when "000" => -- STANDBY
						enable_2v4_dual_supply	<= '1';	
						enable_source_selector	<= '0';
						enable_shunt	<= '0';	
						enable_driver	<= '0';

						if (button_1_TRIG = '1') then 
							driving_state <= "001";
						end if;
						
					when "001" => -- SINGLE_PULSE
						enable_2v4_dual_supply	<= '1';	
						enable_shunt	<= '1';	
						enable_driver	<= '1';
						enable_source_selector	<= '1';
						if (global_counter <= TRES_2) then 
							source <= "111";	-- src8 (Driver)
							driver_signal <= '1';
						elsif ((global_counter <= TRES_2 + SHUNT_DELAY) or shunt_reg = 1) then --shunt_reg = 1 means no shunt should be connected
							source <= "100";	-- src5 (GND)
							driver_signal <= '0';
						else 
							source <= "101";	-- src6 (Shunt)
							driver_signal <= '0';
						end if;

						if (button_1_TRIG = '1') then 
							driving_state <= "010";
						end if;

					when "010" => -- COUNTER_PULSE
						enable_2v4_dual_supply	<= '1';	
						enable_source_selector	<= '1';
						enable_shunt	<= '1';	
						enable_driver	<= '1';

						if (global_counter <= TRES_1) then 
							source <= "111";	-- src8 (Driver)
						     driver_signal <= '1';
						elsif ((global_counter <= TRES_1 + SHUNT_DELAY) or shunt_reg = 1) then
							source <= "100";	-- src5 (GND)
							driver_signal <= '0';
						else
							source <= "101";	-- src6 (Shunt)
							driver_signal <= '0';
						end if;

						if (button_1_TRIG = '1') then 
							driving_state <= "011";
						end if;
						
					when "011" => --FEEDBACK SINGLE PULSE
						enable_2v4_dual_supply	<= '1';	
						enable_shunt	<= '1';	
						enable_driver	<= '0';
						enable_source_selector	<= '1';
						
						if (global_counter <= TRES_2) then
							driver_signal <= '1';
						else
							driver_signal <= '0';
						end if;
						
						if (global_counter > TRES_2 + T_FB_GND and shunt_reg = 1) then
							source <= "100"; --GND
						else
							source <= "110"; --Feedback
						end if;

						if (button_1_TRIG = '1') then 
							driving_state <= "100";
						end if;
						
					when "100" => --FEEDBACK COUNTERPULSE
						enable_2v4_dual_supply	<= '1';	
						enable_source_selector	<= '1';
						enable_shunt	<= '1';	
						enable_driver	<= '0';
                        source <= "110"; --Feedback

						if (global_counter <= TRES_1) then
							driver_signal <= '1';
						else 
							driver_signal <= '0';
						end if;
	
						if (button_1_TRIG = '1') then 
							driving_state <= "000";
						end if;
				    
					when others =>
						driving_state <= "000";
				end case;

				-- allow shunt cycling with button 2
				if (button_2_TRIG = '1') then
					if (shunt_reg >= 8) then
						shunt_reg <= 1; --not connected. acts as a flag value to not switch source to shunt.
					elsif (shunt_reg = 1) then
						shunt_reg <= 3;
					else
						shunt_reg <= shunt_reg + 1;
					end if;
				end if;
				shunt <= std_logic_vector(to_unsigned(shunt_reg - 1, 3)); -- convert shunt_reg to a 3-bit logic vector. subtract 1 to shift range from 1-8 to 0-7.
				
				if (global_counter >= TSLOW) then
					global_counter <= 0;
				else 
					global_counter <= global_counter + 1;
				end if;    
						
			end if;
		end process;
			

LED_driver_obj : LED_driver port map (clock, driving_state, shunt_reg, LED_rgb, LEDs_yellow);
button_1_obj : button_debouncer port map (clock, button_1_IN, button_1, button_1_TRIG);
button_2_obj : button_debouncer port map (clock, button_2_IN, button_2, button_2_TRIG);

shunt_a0 <= shunt(0);
shunt_a1 <= shunt(1);
shunt_a2 <= shunt(2);
source_a4 <= source(0);
source_a5 <= source(1);
source_a6 <= source(2);

led0_r <= LED_rgb(0);
led0_g <= LED_rgb(1);
led0_b <= LED_rgb(2);
led <= LEDs_yellow;

end structural;



