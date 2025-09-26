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
		LspMessage? data = io_handler::read(tmem);
		if (catch excuse = data)
		{
			// log::debug("data could not be read");
		}
		else
		{
			log::debug("got data: %s", data);
		}
	};
	log::debug("BYE!!!!");
	return 0;
}
