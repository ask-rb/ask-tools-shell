# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"
require "ask/tools/shell/file_mutation_queue"

class FileMutationQueueTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("queue_test")
    @file = File.join(@tmpdir, "test.txt")
    File.write(@file, "hello world")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_initial_size_zero
    queue = Ask::Tools::Shell::FileMutationQueue.new
    assert_equal 0, queue.size
  end

  def test_stage_adds_mutation
    queue = Ask::Tools::Shell::FileMutationQueue.new
    queue.stage(@file) { |c| c.gsub("original", "modified") }
    assert_equal 1, queue.size
  end

  def test_apply_modifies_file
    queue = Ask::Tools::Shell::FileMutationQueue.new
    queue.stage(@file) { |c| c.gsub("world", "ruby") }
    results = queue.apply!
    assert_equal 1, results.size
    assert results.first[:success]
    assert_equal "hello ruby", File.read(@file)
  end

  def test_apply_multiple_files
    f2 = File.join(@tmpdir, "b.txt")
    File.write(f2, "file b")
    queue = Ask::Tools::Shell::FileMutationQueue.new
    queue.stage(@file) { |c| c.upcase }
    queue.stage(f2) { |c| c.upcase }
    results = queue.apply!
    assert_equal 2, results.size
    assert results.all? { |r| r[:success] }
    assert_equal "HELLO WORLD", File.read(@file)
    assert_equal "FILE B", File.read(f2)
  end

  def test_clear_removes_all
    queue = Ask::Tools::Shell::FileMutationQueue.new
    queue.stage(@file) { |c| c.upcase }
    queue.clear!
    assert_equal 0, queue.size
  end

  def test_size_after_stage
    queue = Ask::Tools::Shell::FileMutationQueue.new
    assert_equal 0, queue.size
    queue.stage(@file) { |c| c }
    assert_equal 1, queue.size
    queue.stage(@file) { |c| c }
    assert_equal 2, queue.size
  end

  def test_apply_returns_size_info
    queue = Ask::Tools::Shell::FileMutationQueue.new
    queue.stage(@file) { |c| c + " world" }
    results = queue.apply!
    assert_equal 11, results.first[:original_size]
    assert_equal 17, results.first[:new_size]
  end

  def test_apply_error_class_exists
    assert Ask::Tools::Shell::FileMutationQueue::ApplyError < StandardError
  end
end
