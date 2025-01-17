
# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/commands/build_command'
require 'rubygems/package'

class TestGemCommandsBuildCommand < Gem::TestCase

  def setup
    super

    @gem = util_spec 'some_gem' do |s|
      s.rubyforge_project = 'example'
    end

    @cmd = Gem::Commands::BuildCommand.new
  end

  def test_execute
    gemspec_file = File.join(@tempdir, @gem.spec_name)

    File.open gemspec_file, 'w' do |gs|
      gs.write @gem.to_ruby
    end

    util_test_build_gem @gem, gemspec_file
  end

  def test_execute_bad_spec
    @gem.date = "2010-11-08"

    gemspec_file = File.join(@tempdir, @gem.spec_name)

    File.open gemspec_file, 'w' do |gs|
      gs.write @gem.to_ruby.sub(/11-08/, "11-8")
    end

    @cmd.options[:args] = [gemspec_file]

    out, err = use_ui @ui do
      capture_io do
        assert_raises Gem::MockGemUi::TermError do
          @cmd.execute
        end
      end
    end

    assert_equal "", out
    assert_match(/invalid date format in specification/, err)

    assert_equal '', @ui.output
    assert_equal "ERROR:  Error loading gemspec. Aborting.\n", @ui.error
  end

  def test_execute_missing_file
    @cmd.options[:args] = %w[some_gem]
    use_ui @ui do
      assert_raises Gem::MockGemUi::TermError do
        @cmd.execute
      end
    end

    assert_equal '', @ui.output
    assert_equal "ERROR:  Gemspec file not found: some_gem\n", @ui.error
  end

  def test_can_find_gemspecs_without_dot_gemspec
    gemspec_file = File.join(@tempdir, @gem.spec_name)

    File.open gemspec_file + ".gemspec", 'w' do |gs|
      gs.write @gem.to_ruby
    end

    util_test_build_gem @gem, gemspec_file
  end

  def util_test_build_gem(gem, gemspec_file, check_licenses=true)
    @cmd.options[:args] = [gemspec_file]

    use_ui @ui do
      Dir.chdir @tempdir do
        @cmd.execute
      end
    end

    output = @ui.output.split "\n"
    assert_equal "  Successfully built RubyGem", output.shift
    assert_equal "  Name: some_gem", output.shift
    assert_equal "  Version: 2", output.shift
    assert_equal "  File: some_gem-2.gem", output.shift
    assert_equal [], output

    if check_licenses
      assert_match "WARNING:  licenses is empty", @ui.error
    end

    gem_file = File.join @tempdir, File.basename(gem.cache_file)
    assert File.exist?(gem_file)

    spec = Gem::Package.new(gem_file).spec

    assert_equal "some_gem", spec.name
    assert_equal "this is a summary", spec.summary
  end

  def test_execute_force
    gemspec_file = File.join(@tempdir, @gem.spec_name)

    @gem.send :remove_instance_variable, :@rubygems_version

    File.open gemspec_file, 'w' do |gs|
      gs.write @gem.to_ruby
    end

    @cmd.options[:args] = [gemspec_file]
    @cmd.options[:force] = true

    util_test_build_gem @gem, gemspec_file, false
  end

  CERT_FILE = cert_path 'public3072'
  SIGNING_KEY = key_path 'private3072'

  def test_build_signed_gem
    skip 'openssl is missing' unless defined?(OpenSSL::SSL)

    trust_dir = Gem::Security.trust_dir

    spec = util_spec 'some_gem' do |s|
      s.signing_key = SIGNING_KEY
      s.cert_chain = [CERT_FILE]
    end

    gemspec_file = File.join(@tempdir, spec.spec_name)

    File.open gemspec_file, 'w' do |gs|
      gs.write spec.to_ruby
    end

    util_test_build_gem spec, gemspec_file

    trust_dir.trust_cert OpenSSL::X509::Certificate.new(File.read(CERT_FILE))

    gem = Gem::Package.new(File.join(@tempdir, spec.file_name),
                           Gem::Security::HighSecurity)
    assert gem.verify
  end

end
