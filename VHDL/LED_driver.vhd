library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity LED_driver is
	port (
		clock 		: in  std_logic;
		driving_state  	: in  std_logic_vector(2 downto 0);
		shunt_number 	: in  natural range 0 to 8;
		LED_rgb		: out std_logic_vector(2 downto 0);
		LEDs_yellow 	: out std_logic_vector(3 downto 0)
		);
end LED_driver;

architecture rtl of LED_driver is
	constant CLK_FREQ : natural := 12;  -- [MHz]
	constant BLINK_FREQ : natural := 5; -- [Hz] frequency for blinking LED
	constant BLINK_CNT : natural := (CLK_FREQ * 1000 * 1000)/(BLINK_FREQ); -- amount of clock cycles in a blinking period

	signal blink_counter : natural range 0 to BLINK_CNT; 
	signal color : std_logic_vector(2 downto 0);
	signal blink : std_logic := '0';
	

begin
	process (clock) is
		begin
			if rising_edge(clock) then
				if (shunt_number = 1) then
					LEDs_yellow <= "0000"; --shunt off
				else
					LEDs_yellow <= std_logic_vector(to_unsigned(shunt_number, 4));
				end if;

				case driving_state is
					when "000" => --STANDBY
						blink <= '0';
						color <= "010"; --green
					when "001" => --SINGLE PULSE
						blink <= '0';
						color <= "011"; --yellow
					when "010" => --COUNTER PULSE
						blink <= '0';
						color <= "001"; --blue
                    when "011" => --FEEDBACK SINGLE PULSE
                        blink <= '1';
                        color <= "011"; --yellow
					when "100" => --FEEDBACK COUNTER PULSE
						blink <= '1';
						color <= "001"; --blue
					when others =>
						blink <= '0';
						color <= "000"; --off
				end case;


				if (blink_counter = BLINK_CNT or blink = '0') then
					blink_counter <= 0;
				else
					blink_counter <= blink_counter + 1;
				end if;

				if (blink_counter < BLINK_CNT/2) then
					LED_rgb <= not color;
				else
					LED_rgb <= "111"; --all off
				end if;
			end if;
	end process;
end rtl;
