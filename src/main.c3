module lsp;
import std::io;
import std::core::log;
import std::thread;
import std::time;

fn int main(String[] args)
{
	log::set_priority_all(LogPriority.VERBOSE);
	log::info("STARTUP");
	io_handler::init();
	defer io_handler::quit();

	LspProject project;
	project.init(mem);
	defer project.free();

	log::info("Lsp initialized!");

	while LOOP: (true) @pool()
	{
		LspMessage? data = io_handler::read(tmem);
		if (catch err = data)
		{
			if (err == io_handler::NO_NEW_DATA)
			{
				//TODO: How long?
				thread::sleep(time::ms(1));
				continue;
			}

			log::error("Stream read error encountered: %s", err);
			continue;
		}
		
		switch (data.method)
		{
			case INITIALIZE:
                initialize::response(tmem, &data);
				break;
			case DID_OPEN:
                project.open_file(data.params.did_open.document);
				break;
            case DID_CLOSE:
                project.close_file(data.params.did_close.document);
				break;
			case SHUTDOWN:
                shutdown::response(tmem, &data);
				break;
			case EXIT:
				log::info("Exit notification received. Terminating process.");
                break LOOP;
			default:
				log::verbose("Unhandled LSP method: %s", data.method);
				break;
		}
	};

	return 0;
}
