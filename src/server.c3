module lsp::server;
import lsp::io_handler;
import lsp::analysis;
import lsp::translator;
import lsp::msg_handler;
import lsp::core::config;
import lsp::core::logger;
import std::io;
import std::core::log;
import std::thread;
import std::time;
import uri;

bool is_ready;
bool running @local;
LogLevel log_level;
String log_path;
LspProject project;

fn void start(CliArgs args)
{
	log::set_logger(&&(LspLogger){});
	log::set_priority_all(VERBOSE);

	if (catch err = @try(log_level, LogLevel::lookup_field(name, args.log_level)))
	{
		log::error("Unkown log-level %s", args.log_level);
		log_level = ERROR;
	}
	
	io_handler::init();

	project.init(mem);
	defer project.free();

	running = true;

	if (try log = args.log_path.get())
	{
		log::info("Set logging to path = %s", log);
		log_path = log;
	}

	logger::init();
	defer logger::close();

	if (try path = args.stdlib_path.get())
	{
		process_stdlib(path);
	}

	loop();
}

fn void loop()
{
	while (running) @pool()
	{
		LspMessage? data = io_handler::read(tmem);
		if (catch err = data)
		{
			log::error("Stream read error encountered: %s", err);
			continue;
		}

		dispatch(&data);
	};
}

fn void dispatch(LspMessage* message)
{
	switch (message.method)
	{
		case INITIALIZE:
			initialize::response(tmem, message);
			if (try value = message.params.initialize.trace.get())
			{
				if (value == VERBOSE)
				{
					log::set_priority_all(VERBOSE);
				}
			}
			if (try value = message.params.initialize.workspace_folders.get())
			{
				WorkspaceFolder wf = value[0];
				config::load(&project, wf, mem);
			}
		case INITIALIZED:
			log::info("received Initialized");
			is_ready = true;
			project.process_config();
		case DID_OPEN:
			project.open_file(message.params.did_open.document);
		case DID_CHANGE:
			project.change_file(message.params.did_change);
		case DID_CLOSE:
			project.close_file(message.params.did_close.document.uri);
		case COMPLETION:
			completion::response(tmem, &project, message);
		case HOVER:
			hover::response(tmem, &project, message);
		case DEFINITION:
			goto_definition::response(tmem, &project, message);
		case SET_TRACE:
			{
			}
		case SHUTDOWN:
			shutdown::response(tmem, message);
		case EXIT:
			log::info("Exit notification received. Terminating process.");
			running = false;
		default:
			log::verbose("Unhandled LSP method: %s", message.method);
	}
}

fn void process_stdlib(String std_path) => @pool()
{
	Path path = path::tnew(std_path)!!;
	PathWalker walker = fn bool? (Path p, bool is_dir, void* data)
	{
		if (is_dir) return false;
		Uri file_uri              = uri::from_file_path(tmem, (String)p);
		DocumentUri formatted_uri = (DocumentUri)file_uri.to_raw_string(tmem);
		project.open_file({ .uri = formatted_uri, }, true);
		return false;
	};
	path.walk(walker, null)!!;
	log::warn("Finsihed parsing stdlib");
} 
