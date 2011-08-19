require './test/helper'
require 'fog'

Fog.mock!

class FogTest < Test::Unit::TestCase
  context "" do

    setup do
      @fog_directory = 'papercliptests'

      @credentials = {
        :provider               => 'AWS',
        :aws_access_key_id      => 'ID',
        :aws_secret_access_key  => 'SECRET'
      }

      @connection = Fog::Storage.new(@credentials)
      @connection.directories.create(
        :key => @fog_directory
      )

      @options = {
        :fog_directory    => @fog_directory,
        :fog_credentials  => @credentials,
        :fog_host         => nil,
        :fog_file         => {:cache_control => 1234},
        :path             => ":attachment/:basename.:extension",
        :storage          => :fog
      }

      rebuild_model(@options)
    end

    should "be extended by the Fog module" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Fog)
    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown do
        @file.close
        directory = @connection.directories.new(:key => @fog_directory)
        directory.files.each {|file| file.destroy}
        directory.destroy
      end

      context "without a bucket" do
        setup do
          @connection.directories.get(@fog_directory).destroy
        end

        should "create the bucket" do
          assert @dummy.save
          assert @connection.directories.get(@fog_directory)
        end
      end

      context "with a bucket" do
        should "succeed" do
          assert @dummy.save
        end
      end

      context "without a fog_host" do
        context "with fog_public true" do
          setup do
            rebuild_model(@options.merge(:fog_host => nil, :fog_public => true))
            @dummy = Dummy.new
            @dummy.avatar = StringIO.new('.')
            @dummy.save
          end

          should "provide a public url" do
            assert @dummy.avatar.url =~ %r{^https://papercliptests.s3.amazonaws.com/avatars(%2F|/)stringio.txt\?\d+$}, "#{@dummy.avatar.url.inspect} did not match expected"
          end
        end

        context "with fog_public false" do
          setup do
            rebuild_model(@options.merge(:fog_host => nil, :fog_public => false))
            @dummy = Dummy.new
            @dummy.avatar = StringIO.new('.')
            @dummy.save
          end

          should "provide a public url" do
            assert @dummy.avatar.url =~ %r{^https://s3.amazonaws.com/papercliptests/avatars/stringio.txt\?AWSAccessKeyId=\w+&Signature=\w+&Expires=\d+&\d+$}, "#{@dummy.avatar.url.inspect} did not match expected"
          end
        end
      end

      context "with a fog_host" do
        context "with fog_public true" do
          setup do
            rebuild_model(@options.merge(:fog_host => 'http://example.com', :fog_public => true))
            @dummy = Dummy.new
            @dummy.avatar = StringIO.new('.')
            @dummy.save
          end

          should "provide a public url" do
            assert @dummy.avatar.url =~ %r{^http://example\.com/avatars%2Fstringio.txt\?\d+$}, "#{@dummy.avatar.url.inspect} did not match expected"
          end
        end

        context "with fog_public false" do
          setup do
            rebuild_model(@options.merge(:fog_host => 'http://example.com', :fog_public => false))
            @dummy = Dummy.new
            @dummy.avatar = StringIO.new('.')
            @dummy.save
          end

          should "provide a public url" do
            # This does not currently work. See lib/paperclip/storage/fog.rb
            #assert @dummy.avatar.url =~ %r{^http://example\.com/avatars%2Fstringio.txt\?AWSAccessKeyId=\w+&Signature=\w+&Expires=\d+&\d+$}, "#{@dummy.avatar.url.inspect} did not match expected"
          end
        end
      end

      context "with a fog_host that includes a wildcard placeholder" do
        setup do
          rebuild_model(
            :fog_directory    => @fog_directory,
            :fog_credentials  => @credentials,
            :fog_host         => 'http://img%d.example.com',
            :path             => ":attachment/:basename.:extension",
            :storage          => :fog
          )
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert @dummy.avatar.url =~ /^http:\/\/img[0123]\.example\.com\/avatars%2Fstringio\.txt\?\d*$/, "#{@dummy.avatar.url.inspect} did not match expected"
        end
      end

    end

    context "when unassigned" do
      setup do
        rebuild_model(@options.merge(:default_url => "/:attachment/404.jpg"))
        @dummy = Dummy.new
        @dummy.avatar = nil
        @dummy.save
      end

      should "be missing URL" do
        assert_equal %q{/avatars/404.jpg}, @dummy.avatar.url
      end
    end
  end
end
