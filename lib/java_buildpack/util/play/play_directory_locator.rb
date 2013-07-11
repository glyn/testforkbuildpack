# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/play'

module JavaBuildpack::Util::Play

  # Locate a Play application directory in the given application directory matching the given filter.
  #
  # @param [String] app_dir the application directory
  # @param [Proc] filter a filter returning a Boolean when passes a candidate Play application directory
  # @return [Dir, nil] the located Play application directory or `nil` if there is no such
  # @raise if more than one Play application directory is located
  def self.locate_play_application(app_dir, &filter)
    # A Play application may reside directly in the application directory or in a direct subdirectory of the
    # application directory.
    roots = Dir[app_dir, File.join(app_dir, '*')].select &filter
    raise "Play application detected in multiple directories: #{roots}" if roots.size > 1
    roots.first
  end

end