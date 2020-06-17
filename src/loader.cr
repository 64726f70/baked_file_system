require "./loader/*"

path = File.expand_path ARGV[0_i32], ARGV[1_i32]
BakedFileSystem::Loader.load STDOUT, path
