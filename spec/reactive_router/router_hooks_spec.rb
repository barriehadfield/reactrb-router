require 'spec_helper'
require 'reactive_router/test_components'

describe "Router class", js: true do

  it "can have a #history hook" do

    mount "TestRouter" do
      class TestRouter < React::Router

        # def history
        #   browser_history
        # end

        alias_method :history, :browser_history  # shorthand for above

        def routes
          route("/react_test/:test_id", mounts: App)
        end
      end
    end

    page.should have_content("Rendering App: No Children")
  end

  it "can have a #create_element hook" do
    mount "TestRouter" do
      class TestRouter < React::Router

        param :_onCreateElement, type: Proc

        def create_element(component, component_params)
          params._onCreateElement component.name
          if component.name == "App"
            React.create_element(component, component_params.merge(optional_param: "I am the App"))
          elsif component.name == "Child1"
            component_params[:optional_param] = "I am a Child"
          elsif component.name == "Child2"
            React.create_element(component, component_params.merge(optional_param: "I am also a Child")).to_n
          end
        end

        def routes
          route("/", mounts: App) do
            route("/child1", mounts: Child1)
            route("/child2", mounts: Child2)
            route("/child3", mounts: Child3)
          end
        end
      end
    end

    page.should have_content("Rendering App: No Children")
    page.evaluate_script("window.ReactRouter.hashHistory.push('child1')")
    page.should have_content("I am a Child")
    page.evaluate_script("window.ReactRouter.hashHistory.push('child2')")
    page.should have_content("I am also a Child")
    page.evaluate_script("window.ReactRouter.hashHistory.push('child3')")
    page.should have_content("Child3 got routed")
    event_history_for("CreateElement").flatten.should eq(["App", "Child1", "App", "Child2", "App", "Child3", "App"])

  end

  xit "can have a #stringify_query hook" do
    mount "TestRouter" do
      class TestRouter < React::Router

        param :_onUpdate, type: Proc

        def stringify_query(query)
          params._onUpdate query[:foo]
        end

        def routes
          route("/", mounts: App) do
            route("/child1", mounts: Child1)
          end
        end
      end
    end

    page.evaluate_script("window.ReactRouter.hashHistory.push({pathname: 'child1', query: {foo: 12}})")
    event_history_for("Update").flatten.should eq(["12"])
  end

  it "can have a #parse_query_string hook"

  it "can have a #on_error hook" do
    mount "TestRouter" do
      class TestRouter < React::Router

        param :_onError, type: Proc

        def on_error(message)
          params._onError message.to_s
        end

        def routes
          route("/", mounts: App) do
            route("/test1", mounts: App) do |ct|
              puts "building test1 routes now"
              TestRouter.promise = ct.promise.fail { |msg| "Rejected: #{msg}" }
            end
            route("/test2", mounts: lambda  do |ct| puts "building test2 route"; TestRouter.promise = ct.promise.then do |id|
              Object.const_get id
          end
          end )
          end
        end
      end
    end

    page.evaluate_script("window.ReactRouter.hashHistory.push({pathname: 'test2'})")
    run_on_client { TestRouter.promise.resolve("Child1") }
    page.should have_content("Child1 got routed")

    page.evaluate_script("window.ReactRouter.hashHistory.push({pathname: '/'})")
    page.evaluate_script("window.ReactRouter.hashHistory.push({pathname: 'test1/boom'})")
    run_on_client { TestRouter.promise.reject("This is never going to work") }
    page.should have_content("Rendering App: No Children")

    page.evaluate_script("window.ReactRouter.hashHistory.push({pathname: 'test2'})")
    run_on_client { TestRouter.promise.resolve("BOGUS") }
    page.should have_content("Rendering App: No Children")

    event_history_for("Error").flatten.should eq(["Rejected: This is never going to work", "uninitialized constant Object::BOGUS"])

  end

  it "can have a #on_update hook" do
    mount "TestRouter" do
      class TestRouter < React::Router

        param :_onUpdate, type: Proc

        def on_update(props, state)
          params._onUpdate state[:location][:pathname]
        end

        def routes
          route("/", mounts: App) do
            route("/child1", mounts: Child1)
          end
        end
      end
    end

    page.evaluate_script("window.ReactRouter.hashHistory.push('child1')")
    event_history_for("Update").flatten.should eq(["/child1"])
  end

  it "can redefine the #render method" do
    mount "TestRouter" do
      class TestRouter < React::Router

        param :_onRender, type: Proc

        def render
          params._onRender("rendered")
          super
        end

        def routes
          route("/", mounts: App)
        end
      end
    end

    page.should have_content("Rendering App: No Children")
    event_history_for("Render").flatten.should eq(["rendered"])

  end
end
