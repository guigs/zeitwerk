# frozen_string_literal: true

require "test_helper"

class TestGemInflector < LoaderTest
  def with_gem
    files = [
      ["lib/my_gem.rb", <<-EOS],
        loader = Zeitwerk::Loader.for_gem
        loader.enable_reloading
        loader.setup

        module MyGem
        end
      EOS
      ["lib/my_gem/foo.rb", "MyGem::Foo = true"],
      ["lib/my_gem/version.rb", "MyGem::VERSION = '1.0.0'"],
      ["lib/my_gem/ns/version.rb", "MyGem::Ns::Version = true"]
    ]
    with_files(files) do
      with_load_path("lib") do
        assert require("my_gem")
        yield
      end
    end
  end

  def with_gem_extension
    files = [
      ["lib/ns1/ns2/my_gem.rb", <<-EOS],
        module Ns1
          module Ns2
          end
        end

        loader = Zeitwerk::Loader.for_gem
        loader.enable_reloading
        loader.setup

        module Ns1::Ns2::MyGem
        end
      EOS
      ["lib/ns1/ns2/my_gem/foo.rb", "Ns1::Ns2::MyGem::Foo = true"],
      ["lib/ns1/ns2/my_gem/version.rb", "Ns1::Ns2::MyGem::VERSION = '1.0.0'"],
      ["lib/ns1/ns2/my_gem/ns/version.rb", "Ns1::Ns2::MyGem::Ns::Version = true"]
    ]
    with_files(files) do
      with_load_path("lib") do
        assert require("ns1/ns2/my_gem")
        yield
      end
    end
  end

  test "the constant for my_gem/version.rb is inflected as VERSION" do
    with_gem { assert_equal "1.0.0", MyGem::VERSION }
  end

  test "the constant for my_gem/version.rb is inflected as VERSION (extension)" do
    on_teardown { remove_const :Ns1 }

    with_gem_extension { assert_equal "1.0.0", Ns1::Ns2::MyGem::VERSION }
  end

  test "other possible version.rb are inflected normally" do
    with_gem { assert MyGem::Ns::Version }
  end

  test "other possible version.rb are inflected normally (extension)" do
    on_teardown { remove_const :Ns1 }

    with_gem_extension { assert Ns1::Ns2::MyGem::Ns::Version }
  end

  test "works as expected for other files" do
    with_gem { assert MyGem::Foo }
  end

  test "works as expected for other files (extension)" do
    on_teardown { remove_const :Ns1 }

    with_gem_extension { assert Ns1::Ns2::MyGem::Foo }
  end
end
