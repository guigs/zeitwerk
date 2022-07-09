# frozen_string_literal: true

require "test_helper"

class TestForGemExtension < LoaderTest
  MY_GEM_EXTENSION = ["lib/ns1/ns2/my_gem.rb", <<~RUBY]
    # Emulates a require to an external gem that defines Ns1::Ns2.
    module Ns1
      module Ns2
      end
    end

    $for_gem_extension_test_loader = Zeitwerk::Loader.for_gem
    $for_gem_extension_test_loader.enable_reloading
    $for_gem_extension_test_loader.setup

    module Ns1::Ns2::MyGem
    end
  RUBY

  def with_my_gem_extension(files = [MY_GEM_EXTENSION], rq: true, load_path: "lib")
    with_files(files) do
      with_load_path(load_path) do
        if rq
          assert require("ns1/ns2/my_gem.rb")
          assert Ns1::Ns2::MyGem
        end
        yield
      end
    end
  end

  def teardown
    super
    remove_const :Ns1 if Object.const_defined?(:Ns1)
  end

  test "sets things correctly" do
    files = [
      MY_GEM_EXTENSION,
      ["lib/ns1/ns2/my_gem/foo.rb", "class Ns1::Ns2::MyGem::Foo; end"],
      ["lib/ns1/ns2/my_gem/foo/bar.rb", "Ns1::Ns2::MyGem::Foo::Bar = true"]
    ]
    with_my_gem_extension(files) do
      assert Ns1::Ns2::MyGem::Foo::Bar

      $for_gem_extension_test_loader.unload
      assert !Ns1::Ns2.const_defined?(:MyGem)

      $for_gem_extension_test_loader.setup
      assert Ns1::Ns2::MyGem::Foo::Bar
    end
  end

  test "is idempotent" do
    $for_gem_extension_test_zs = []
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS]]
      module Ns1
        module Ns2
        end
      end

      $for_gem_extension_test_zs << Zeitwerk::Loader.for_gem
      $for_gem_extension_test_zs.last.enable_reloading
      $for_gem_extension_test_zs.last.setup

      module Ns1::Ns2::MyGem
      end
    EOS

    with_my_gem_extension(files) do
      $for_gem_extension_test_zs.first.unload
      assert !Ns1::Ns2.const_defined?(:MyGem)

      $for_gem_extension_test_zs.first.setup
      assert Ns1::Ns2::MyGem

      assert_equal 2, $for_gem_extension_test_zs.size
      assert_same $for_gem_extension_test_zs.first, $for_gem_extension_test_zs.last
    end
  end

  test "configures the gem inflector by default" do
    with_my_gem_extension do
      assert_instance_of Zeitwerk::GemInflector, $for_gem_extension_test_loader.inflector
    end
  end

  test "configures the conventional name for the gem as tag" do
    with_my_gem_extension do
      assert_equal "ns1-ns2-my_gem", $for_gem_extension_test_loader.tag
    end
  end

  test "does not warn if lib only has expected files" do
    with_my_gem_extension([MY_GEM_EXTENSION], rq: false) do
      assert_silent do
        assert require("ns1/ns2/my_gem")
      end
    end
  end

  test "does not warn if lib has the convenience file after the gem name" do
    on_teardown { delete_loaded_feature "ns1-ns2-my_gem.rb"}

    files = [MY_GEM_EXTENSION, ["lib/ns1-ns2-my_gem.rb", 'require "ns1/ns2/my_gem"']]
    with_my_gem_extension(files, rq: false) do
      assert_silent do
        assert require("ns1-ns2-my_gem")
        assert Ns1::Ns2::MyGem # ensure setup exercices the loader
      end
    end
  end

  test "does not warn if lib only has extra, non-hidden, non-Ruby files" do
    files = [MY_GEM_EXTENSION, ["lib/i18n.yml", ""], ["lib/.vscode", ""]]
    with_my_gem_extension(files, rq: false) do
      assert_silent do
        assert require("ns1/ns2/my_gem")
      end
    end
  end

  test "warns if the lib has an extra Ruby file" do
    files = [MY_GEM_EXTENSION, ["lib/foo.rb", ""]]
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant Foo after the file"
      assert_includes err, File.expand_path("lib/foo.rb")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "does not warn if lib has an extra Ruby file, but it is ignored" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS], ["lib/foo.rb", ""]]
      module Ns1
        module Ns2
        end
      end

      loader = Zeitwerk::Loader.for_gem
      loader.ignore("lib/foo.rb")
      loader.enable_reloading
      loader.setup

      module Ns1::Ns2::MyGem
      end
    EOS
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_empty err
    end
  end

  test "does not warn if lib has an extra Ruby file, but warnings are disabled" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS], ["lib/foo.rb", ""]]
      module Ns1
        module Ns2
        end
      end

      loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      loader.enable_reloading
      loader.setup

      module Ns1::Ns2::MyGem
      end
    EOS
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_empty err
    end
  end

  test "warns if lib has an extra directory" do
    files = [MY_GEM_EXTENSION, ["lib/foo/bar.rb", "Foo::Bar = true"]]
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant Foo after the directory"
      assert_includes err, File.expand_path("lib/foo")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "does not warn if lib has an extra directory, but it is ignored" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      module Ns1
        module Ns2
        end
      end

      loader = Zeitwerk::Loader.for_gem
      loader.ignore("lib/foo")
      loader.enable_reloading
      loader.setup

      module Ns1::Ns2::MyGem
      end
    EOS
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_empty err
    end
  end

  test "does not warn if lib has an extra directory, but it has no Ruby files" do
    files = [MY_GEM_EXTENSION, ["lib/tasks/newsletter.rake", ""]]
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_empty err
    end
  end

  test "does not warn if lib has an extra directory, but warnings are disabled" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      module Ns1
        module Ns2
        end
      end

      loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      loader.enable_reloading
      loader.setup

      module Ns1::Ns2::MyGem
      end
    EOS
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_empty err
    end
  end

  test "warnings do not assume the namespace directory is the tag" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      module Ns1
        module Ns2
        end
      end

      loader = Zeitwerk::Loader.for_gem
      loader.tag = "foo"
      loader.enable_reloading
      loader.setup

      module Ns1::Ns2::MyGem
      end
    EOS
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant Foo after the directory"
      assert_includes err, File.expand_path("lib/foo")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "warnings use the gem inflector" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      module Ns1
        module Ns2
        end
      end

      loader = Zeitwerk::Loader.for_gem
      loader.inflector.inflect("foo" => "BAR")
      loader.enable_reloading
      loader.setup

      module Ns1::Ns2::MyGem
      end
    EOS
    with_my_gem_extension(files, rq: false) do
      _out, err = capture_io do
        assert require("ns1/ns2/my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant BAR after the directory"
      assert_includes err, File.expand_path("lib/foo")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "raises if the gem has no lib directory" do
    files = [["ns1/ns2/my_gem.rb", MY_GEM_EXTENSION.last]]
    e = assert_raises(Zeitwerk::LibNotFound) do
      with_my_gem_extension(files, load_path: ".")
    end
    assert_match %r/\AGem lib directory not found for .*my_gem.rb\z/, e.message
  end

  test "raises if the extended namespace is not already defined" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS]]
      Zeitwerk::Loader.for_gem.setup
    EOS
    with_my_gem_extension(files, rq: false) do
      e = assert_raises(Zeitwerk::NamespaceNotFound) do
        assert require("ns1/ns2/my_gem")
      end
      assert_includes e.message, "The namespace Ns1 was not found."
    end
  end

  test "raises if the extended namespace is not already defined" do
    files = [["lib/ns1/ns2/my_gem.rb", <<~EOS]]
      module Ns1
      end

      Zeitwerk::Loader.for_gem.setup
    EOS
    with_my_gem_extension(files, rq: false) do
      e = assert_raises(Zeitwerk::NamespaceNotFound) do
        assert require("ns1/ns2/my_gem")
      end
      assert_includes e.message, "The namespace Ns1::Ns2 was not found."
    end
  end
end
