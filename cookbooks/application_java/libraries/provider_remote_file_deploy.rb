#
# Author:: Jesse Campbell (<hikeit@gmail.com>)
# Copyright:: Copyright (c) 2013 Jesse Campbell
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider/remote_file'

class Chef
  class Provider
    class RemoteFile
      class Deploy < Chef::Provider::RemoteFile

        def initialize(new_resource, run_context)
          @deploy_resource = new_resource
          @new_resource = Chef::Resource::RemoteFile.new(@deploy_resource.name)
          @new_resource.path ::File.join(@deploy_resource.destination, ::File.basename(@deploy_resource.repository))
          @new_resource.source @deploy_resource.repository

          @new_resource.owner @deploy_resource.user
          @new_resource.group @deploy_resource.group
          @action = action
          super(@new_resource, run_context) if defined?(super)
        end

        def target_revision
          action_sync
        end
        alias :revision_slug :target_revision

        def action_sync
          create_dir_unless_exists(@deploy_resource.destination)
          purge_old_downloads
          action_create
        end

        private

        def create_dir_unless_exists(dir)
          if ::File.directory?(dir)
            Chef::Log.debug "#{@new_resource} not creating #{dir} because it already exists"
            return false
          end
          converge_by("create new directory #{dir}") do
            begin
              FileUtils.mkdir_p(dir)
              Chef::Log.debug "#{@new_resource} created directory #{dir}"
              if @new_resource.user
                FileUtils.chown(@new_resource.user, nil, dir)
                Chef::Log.debug("#{@new_resource} set user to #{@new_resource.user} for #{dir}")
              end
              if @new_resource.group
                FileUtils.chown(nil, @new_resource.group, dir)
                Chef::Log.debug("#{@new_resource} set group to #{@new_resource.group} for #{dir}")
              end
            rescue => e
              raise Chef::Exceptions::FileNotFound.new("Cannot create directory #{dir}: #{e.message}")
            end
          end
        end

        def purge_old_downloads
          converge_by("purge old downloads") do
            Dir.glob( "#{@deploy_resource.destination}/*" ).each do |direntry|
              unless direntry == @new_resource.path
                FileUtils.rm_rf( direntry )
                Chef::Log.info("#{@new_resource} purged old download #{direntry}")
              end
            end
          end
        end

      end
    end
  end
end
