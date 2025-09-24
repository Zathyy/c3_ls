module lsp;
import std::io;
import std::core::log;

fn int main(String[] args)
{
	log::set_priority_all(LogPriority.VERBOSE);
	log::debug("STARTUP");
	io_handler::init();
	defer io_handler::quit();
	while (true)
	{
		// log::debug("LOOP!!!");
		String? data = io_handler::read(tmem);
		if (catch excuse = data)
		{
			// log::debug("data could not be read");
		}
		else if (data.len > 0)
		{
			log::debug("got data: %s", data);
		}
	};
	log::debug("BYE!!!!");
	return 0;
}
