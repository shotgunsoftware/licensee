# frozen_string_literal: true

# Git-based project
#
# Analyze a given (bare) Git repository for license information
#
# Project files for this project type will contain the following keys:
#  :name - the file's path relative to the repo root
#  :oid  - the file's OID

autoload :Rugged, 'rugged'

module Licensee
  module Projects
    class GitProject < Licensee::Projects::Project
      attr_reader :revision

      class InvalidRepository < ArgumentError; end

      def initialize(repo, **args)
        @raw_repo = repo

        raise InvalidRepository if repository.head_unborn?

        super(**args)
      end

      def repository
        @repository ||= begin
          return @raw_repo if @raw_repo.is_a? Rugged::Repository

          Rugged::Repository.new(@raw_repo)
        end
      rescue Rugged::OSError, Rugged::RepositoryError
        raise InvalidRepository
      end

      def close
        repository.close
      end

      private

      def commit
        @commit ||= if revision
          commit = repository.rev_parse(revision)
          commit = commit.target until commit.is_a?(Rugged::Commit)
          commit
        else
          repository.last_commit
        end
      end

      MAX_LICENSE_SIZE = 64 * 1024

      # Retrieve a file's content from the Git database
      #
      # file - the file hash, including the file's OID
      #
      # Returns a string representing the file's contents
      def load_file(file)
        data, = Rugged::Blob.to_buffer(repository, file[:oid], MAX_LICENSE_SIZE)
        data
      end

      # Returns an array of hashes representing the project's files.
      # Hashes will have the the following keys:
      #  :name - the file's path relative to the repo root
      #  :oid  - the file's OID
      def files
        @files ||= files_from_tree(commit.tree)
      end

      def files_from_tree(tree, dir = '.')
        tree.select { |e| e[:type] == :blob }.map do |entry|
          entry.merge(dir: dir)
        end.compact
      end
    end
  end
end
