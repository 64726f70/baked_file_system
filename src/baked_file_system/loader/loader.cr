require "./string_encoder.cr"

module BakedFileSystem
  module Loader
    class Error < Exception
    end

    def self.load(io : IO, root_path : String)
      if !File.exists? root_path
        raise Error.new "path does not exist: #{root_path}"
      elsif !File.directory? root_path
        raise Error.new "path is not a directory: #{root_path}"
      elsif !File.readable? root_path
        raise Error.new "path is not readable: #{root_path}"
      end

      # Reject hidden entities and directories

      root_path_length = root_path.size
      result = [] of String
      files = Dir.glob(File.join root_path, "**", "*").reject { |path| File.directory?(path) || !(path =~ /(\/\..+)/).nil? }

      files.each do |path|
        compressed = path.ends_with? "gz"

        io << "bake_file BakedFileSystem::BakedFile.new(\n"
        io << "  path:            " << path[root_path_length..-1].dump << ",\n"
        io << "  mime_type:       " << (mime_type(path) || `file -b --mime-type #{path}`.strip).dump << ",\n"
        io << "  size:            " << File.info(path).size << ",\n"
        io << "  compressed:      " << compressed << ",\n"

        File.open path, "rb" do |file|
          io << "  slice:         \""

          StringEncoder.open io do |encoder|
            if compressed
              IO.copy file, encoder
              io << "\".to_slice,\n"

              next
            end

            Compress::Gzip::Writer.open(encoder) { |writer| IO.copy file, writer }
            io << "\".to_slice,\n"
          end
        end

        io << ")\n"
        io << "\n"
      end
    end

    # On macOS, the ancient `file` doesn't handle types like CSS and JS well at all.

    def self.mime_type(path : String)
      case File.extname path
      when ".txt"
        "text/plain"
      when ".htm", ".html"
        "text/html"
      when ".css"
        "text/css"
      when ".js"
        "application/javascript"
      else
        nil
      end
    end
  end
end
