
# frozen_string_literal: true
#
# https://github.com/Shopify/homebrew-shopify/blob/master/chronicle-etl.rb
require "formula"
require "fileutils"

class ChronicleETL < Formula
  module RubyBin
    def ruby_bin
      Formula["ruby"].opt_bin
    end
  end

  class RubyGemsDownloadStrategy < AbstractDownloadStrategy
    include RubyBin

    def fetch(_timeout: nil, **_options)
      ohai("Fetching chronicle-etl from gem source")
      cache.cd do
        ENV["GEM_SPEC_CACHE"] = "#{cache}/gem_spec_cache"
        system("#{ruby_bin}/gem", "fetch", "chronicle-etl", "--version", gem_version)
      end
    end

    def cached_location
      Pathname.new("#{cache}/chronicle-etl-#{gem_version}.gem")
    end

    def cache
      @cache ||= HOMEBREW_CACHE
    end

    def gem_version
      @version ||= @resource&.version if defined?(@resource)
      raise "Unable to determine version; did Homebrew change?" unless @version
      @version
    end

    def clear_cache
      cached_location.unlink if cached_location.exist?
    end
  end

  include RubyBin

  url "chronicle-etl", using: RubyGemsDownloadStrategy
  version "3.0.0"
  sha256 "940b3b37b7ac12aabfa0e6c2a52e2cbbc730d95ad1c12ea881eab9d9d6598b5d"
  depends_on "ruby@2.7"
  depends_on "git"

  def install
    # set GEM_HOME and GEM_PATH to make sure we package all the dependent gems
    # together without accidently picking up other gems on the gem path since
    # they might not be there if, say, we change to a different rvm gemset
    ENV["GEM_HOME"] = prefix.to_s
    ENV["GEM_PATH"] = prefix.to_s

    # Use /usr/local/bin at the front of the path instead of Homebrew shims,
    # which mess with Ruby's own compiler config when building native extensions
    if defined?(HOMEBREW_SHIMS_PATH)
      ENV["PATH"] = ENV["PATH"].sub(HOMEBREW_SHIMS_PATH.to_s, "/usr/local/bin")
    end

    system(
      "#{ruby_bin}/gem",
      "install",
      cached_download,
      "--no-document",
      "--no-wrapper",
      "--no-user-install",
      "--install-dir", prefix,
      "--bindir", bin,
      "--",
      "--skip-cli-build"
    )

    raise "gem install 'chronicle-etl' failed with status #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.success?

    bin.rmtree if bin.exist?
    bin.mkpath

    brew_gem_prefix = "#{prefix}/gems/chronicle-etl-#{version}"

    ruby_libs = Dir.glob("#{prefix}/gems/*/lib")
    exe = "chronicle-etl"
    file = Pathname.new("#{brew_gem_prefix}/bin/#{exe}")
    (bin + file.basename).open("w") do |f|
      f << <<~RUBY
        #!#{ruby_bin}/ruby --disable-gems
        ENV['GEM_HOME']="#{prefix}"
        ENV['GEM_PATH']="#{prefix}"
        ENV['RUBY_BINDIR']="#{ruby_bin}/"
        require 'rubygems'
        $:.unshift(#{ruby_libs.map(&:inspect).join(",")})
        load "#{file}"
      RUBY
    end
  end
end