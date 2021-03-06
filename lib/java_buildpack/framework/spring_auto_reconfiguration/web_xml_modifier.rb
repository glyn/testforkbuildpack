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

require 'java_buildpack/framework'
require 'rexml/document'
require 'rexml/formatters/pretty'

module JavaBuildpack::Framework

  # A class that encapsulates the modification of a +web.xml+ Servlet configuration file for the Auto-reconfiguration
  # framework.  The modifications of +web.xml+ consist of two major behaviors.
  #
  # 1. Augmenting +contextConfigLocation+.  The function starts be enumerating the current +contextConfigLocation+ s.
  #    If none exist, a default configuration is created with +/WEB-INF/application-context.xml+ or
  #    +/WEB-INF/<servlet-name>-servlet.xml+ as the default.  An additional location is then added to the collection of
  #    locations; +classpath:META- INF/cloud/cloudfoundry-auto-reconfiguration-context.xml+ if the +ApplicationContext+
  #    is XML-based, +org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig+ if the
  #    +ApplicationContext+ is annotation-based.
  #
  # 2. Augmenting +contextInitializerClasses+.  The function starts by enumerating the current
  #    +contextInitializerClasses+.  If none exist, a default configuration is created with no value as the default.
  #    The +org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer+ class is then added to the
  #    collection of classes.
  class WebXmlModifier

    # Creates a new instance of the modifier.
    #
    # @param [{REXML::Document}, String, {IO}] source the content of the +web.xml+ file to modify
    def initialize(source)
      @document = REXML::Document.new(source)
    end

    # Make modifications to the root context
    #
    # @return [void]
    def augment_root_context
      if has_context_loader_listener?
        augment_context_config_locations web_app(@document), 'context-param', CONTEXT_LOCATION_DEFAULT
        augment_context_initializer_classes web_app(@document), 'context-param'
      end
    end

    # Make modifications to the the servlet contexts
    #
    # @return [void]
    def augment_servlet_contexts
      servlets.each do |servlet|
        augment_context_config_locations servlet, 'init-param', default_servlet_context_location(servlet)
        augment_context_initializer_classes servlet, 'init-param'
      end
    end

    # Returns a +String+ representation of the modified +web.xml+.
    #
    # @return [String] a +String+ representation of the modified +web.xml+.
    def to_s
      @document.to_s
    end

    private

    CONTEXT_CLASS = 'contextClass'.freeze

    CONTEXT_CLASS_ANNOTATION = 'org.springframework.web.context.support.AnnotationConfigWebApplicationContext'.freeze

    CONTEXT_CONFIG_LOCATION = 'contextConfigLocation'.freeze

    CONTEXT_INITIALIZER_ADDITIONAL = 'org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer'.freeze

    CONTEXT_INITIALIZER_CLASSES = 'contextInitializerClasses'.freeze

    CONTEXT_LOADER_LISTENER = 'ContextLoaderListener'.freeze

    CONTEXT_LOCATION_ADDITIONAL_ANNOTATION = 'org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig'.freeze

    CONTEXT_LOCATION_ADDITIONAL_XML = 'classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml'.freeze

    CONTEXT_LOCATION_DEFAULT = '/WEB-INF/applicationContext.xml'.freeze

    DISPATCHER_SERVLET = 'DispatcherServlet'.freeze

    def additional_context_config_location(root, param_type)
      has_annotation_application_context?(root, param_type) ? CONTEXT_LOCATION_ADDITIONAL_ANNOTATION : CONTEXT_LOCATION_ADDITIONAL_XML
    end

    def augment_context_config_locations(root, param_type, default_location)
      locations_string = xpath(root, "#{param_type}[param-name[contains(text(), '#{CONTEXT_CONFIG_LOCATION}')]]/param-value/text()").first
      locations_string = create_param(root, param_type, CONTEXT_CONFIG_LOCATION, default_location) if !locations_string

      locations = locations_string.value.strip.split(/[,;\s]+/)
      locations << additional_context_config_location(root, param_type)

      locations_string.value = locations.join(' ')
    end

    def augment_context_initializer_classes(root, param_type)
      classes_string = xpath(root, "#{param_type}[param-name[contains(text(), '#{CONTEXT_INITIALIZER_CLASSES}')]]/param-value/text()").first
      classes_string = create_param(root, param_type, CONTEXT_INITIALIZER_CLASSES, '') if !classes_string

      classes = classes_string.value.strip.split(/[,;\s]+/)
      classes << CONTEXT_INITIALIZER_ADDITIONAL

      classes_string.value = classes.join(' ')
    end

    def create_param(root, param_type, name, value)
      param = REXML::Element.new param_type, root

      param_name = REXML::Element.new 'param-name', param
      REXML::Text.new name, true, param_name

      param_value = REXML::Element.new 'param-value', param
      REXML::Text.new value, true, param_value
    end

    def default_servlet_context_location(servlet)
      name = xpath(servlet, 'servlet-name/text()').first.value.strip
      "/WEB-INF/#{name}-servlet.xml"
    end

    def has_annotation_application_context?(root, param_type)
      xpath(root, "#{param_type}/param-name[contains(text(), '#{CONTEXT_CLASS}')]").any?
    end

    def has_context_loader_listener?
      xpath(@document, "/web-app/listener/listener-class[contains(text(), '#{CONTEXT_LOADER_LISTENER}')]").any?
    end

    def servlets
      xpath(@document, "/web-app/servlet[servlet-class[contains(text(), '#{DISPATCHER_SERVLET}')]]")
    end

    def web_app(root)
      xpath(root, '/web-app').first
    end

    def xpath(root, path)
      REXML::XPath.match(root, path)
    end

  end

end
