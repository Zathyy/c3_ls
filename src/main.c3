module lsp;
import std::io;
import std::core::log;

fn int main(String[] args)
{
	log::set_priority_all(LogPriority.VERBOSE);
	log::info("STARTUP");
	io_handler::init();
	defer io_handler::quit();

	LspProject project;
	project.init(mem);
	defer project.free();

	while LOOP: (true) @pool()
	{
		LspMessage? data = io_handler::read(tmem);
		if (catch excuse = data) continue;
		LspAction? action = msg_handler::handle_message(data, tmem);
		if (catch excuse = action)
		{}
		else
		{
			switch (action.type)
			{
			case SHUTDOWN:
				break LOOP;
			case OPEN_FILE:
				LspActionDataOpenFile* open_file = (LspActionDataOpenFile*)action.data;
				project.open_file(open_file.uri, open_file.text);
			case CLOSE_FILE:
				LspActionDataCloseFile* open_file = (LspActionDataCloseFile*)action.data;
				project.close_file(open_file.uri);
			default:
				break;
			}
		}
	};
	log::debug("project: %s", project.files);
	log::info("BYE!!!!");
	return 0;
}
