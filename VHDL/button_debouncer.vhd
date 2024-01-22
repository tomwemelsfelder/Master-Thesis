library ieee;
use ieee.std_logic_1164.all;

entity button_debouncer is
	port (
		clock 		: in  std_logic;
		button_IN  	: in  std_logic;
		button_OUT 	: out std_logic;
		trigger		: out std_logic
		);
end button_debouncer;

architecture rtl of button_debouncer is
	constant CLK_FREQ : natural := 12;  -- [MHz]
	constant T_DEBOUNCE : natural := 50000; -- [us] time button must be LOW to switch state to LOW
	constant CNT_DEBOUNCE : natural := T_DEBOUNCE * CLK_FREQ;

	signal count_debounce : natural range 0 to CNT_DEBOUNCE;

	signal button_STATE : std_logic;
	
begin

	process (clock) is
	begin
		if rising_edge(clock) then
			if (button_IN = '1') then
				if button_STATE = '0' then
					trigger <= '1';
				else 
					trigger <= '0';
				end if;
				button_STATE <= '1';
				button_OUT <= '1';
				count_debounce <= 0;
			else 	
				trigger <= '0';
				if (button_STATE = '1') then
					if (count_debounce >= CNT_DEBOUNCE) then
						button_STATE <= '0';
						button_OUT <= '0';
						count_debounce <= 0;
					else
						count_debounce <= count_debounce + 1;
					end if;
				else
					button_STATE <= '0';
					button_OUT <= '0';
					count_debounce <= 0;
				end if;
			end if; 
			  
		end if;
	end process;
end rtl;

						