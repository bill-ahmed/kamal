require_relative "cli_test_case"

class CliProxyTest < CliTestCase
  test "boot" do
    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/home/kamal-proxy/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE}", output
    end
  end

  test "boot old version" do
    Thread.report_on_exception = false
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :cut, "-d:", "-f2")
      .returns("v0.0.1")
      .at_least_once

    exception = assert_raises do
      run_command("boot").tap do |output|
        assert_match "docker login", output
        assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/home/kamal-proxy/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE}", output
      end
    end

    assert_includes exception.message, "kamal-proxy version v0.0.1 is too old, please reboot to update to at least #{Kamal::Configuration::Proxy::MINIMUM_VERSION}"
  ensure
    Thread.report_on_exception = false
  end

  test "boot correct version" do
    Thread.report_on_exception = false
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :cut, "-d:", "-f2")
      .returns(Kamal::Configuration::Proxy::MINIMUM_VERSION)
      .at_least_once

    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "docker container start kamal-proxy || docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/home/kamal-proxy/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE}", output
    end
  ensure
    Thread.report_on_exception = false
  end

  test "reboot" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet")
      .returns("abcdefabcdef")
      .at_least_once

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with { |*args| args[0..1] == [ :sh, "-c" ] }
      .returns("123")
      .at_least_once

    run_command("reboot", "-y").tap do |output|
      assert_match "docker container stop kamal-proxy on 1.1.1.1", output
      assert_match "Running docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.1", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/home/kamal-proxy/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE} on 1.1.1.1", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target \"abcdefabcdef:80\" --deploy-timeout \"6s\" --buffer-requests --buffer-responses --log-request-header \"Cache-Control\" --log-request-header \"Last-Modified\" --log-request-header \"User-Agent\" on 1.1.1.1", output

      assert_match "docker container stop kamal-proxy on 1.1.1.2", output
      assert_match "Running docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.2", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.2", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/home/kamal-proxy/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE} on 1.1.1.2", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target \"abcdefabcdef:80\" --deploy-timeout \"6s\" --buffer-requests --buffer-responses --log-request-header \"Cache-Control\" --log-request-header \"Last-Modified\" --log-request-header \"User-Agent\" on 1.1.1.2", output
    end
  end

  test "reboot --rolling" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet")
      .returns("abcdefabcdef")
      .at_least_once

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with { |*args| args[0..1] == [ :sh, "-c" ] }
      .returns("123")
      .at_least_once

    run_command("reboot", "--rolling", "-y").tap do |output|
      assert_match "Running docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
    end
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match "docker container start kamal-proxy", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "docker container stop kamal-proxy", output
    end
  end

  test "restart" do
    Kamal::Cli::Proxy.any_instance.expects(:stop)
    Kamal::Cli::Proxy.any_instance.expects(:start)

    run_command("restart")
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter name=^kamal-proxy$", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "kamal-proxy", " --tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "proxy", " --tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    run_command("logs").tap do |output|
      assert_match "Proxy Host: 1.1.1.1", output
      assert_match "Log entry", output
    end
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker logs kamal-proxy --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker logs kamal-proxy --timestamps --tail 10 --follow", run_command("logs", "--follow")
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match "/usr/bin/env ls .kamal/apps | wc -l", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "/usr/bin/env rm -r .kamal/proxy", output
    end
  end

  test "remove with other apps" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info).with(:ls, ".kamal/apps", "|", :wc, "-l").returns("1\n").twice

    run_command("remove").tap do |output|
      assert_match "Not removing the proxy, as other apps are installed, ignore this check with kamal proxy remove --force", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "force remove with other apps" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info).with(:ls, ".kamal/apps", "|", :wc, "-l").returns("1\n").twice

    run_command("remove").tap do |output|
      assert_match "Not removing the proxy, as other apps are installed, ignore this check with kamal proxy remove --force", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "remove_container" do
    run_command("remove_container").tap do |output|
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
    end
  end

  test "remove_image" do
    run_command("remove_image").tap do |output|
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
    end
  end

  test "remove_host_directory" do
    run_command("remove_host_directory").tap do |output|
      assert_match "/usr/bin/env rm -r .kamal/proxy", output
    end
  end

  test "upgrade" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("12345678")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :cut, "-d:", "-f2")
      .returns(Kamal::Configuration::Proxy::MINIMUM_VERSION)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    run_command("upgrade", "-y").tap do |output|
      assert_match "Upgrading proxy on 1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4...", output
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match "docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik", output
      assert_match "docker container stop kamal-proxy", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match "docker network create kamal", output
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match "docker container start kamal-proxy || docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/home/kamal-proxy/.config/kamal-proxy --log-opt max-size=\"10m\" basecamp/kamal-proxy:#{Kamal::Configuration::Proxy::MINIMUM_VERSION}", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match %r{docker rename app-web-latest app-web-latest_replaced_.*}, output
      assert_match "/usr/bin/env mkdir -p .kamal/apps/app/env/roles", output
      assert_match %r{/usr/bin/env .* .kamal/apps/app/env/roles/web.env}, output
      assert_match %r{docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-.* -e KAMAL_CONTAINER_NAME="app-web-latest" -e KAMAL_VERSION="latest" --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size="10m" --label service="app" --label role="web" --label destination dhh/app:latest}, output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target \"12345678:80\" --deploy-timeout \"6s\" --buffer-requests --buffer-responses --log-request-header \"Cache-Control\" --log-request-header \"Last-Modified\" --log-request-header \"User-Agent\"", output
      assert_match "docker container ls --all --filter name=^app-web-12345678$ --quiet | xargs docker stop", output
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match "docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done", output
      assert_match "docker image prune --force --filter label=service=app", output
      assert_match "Upgraded proxy on 1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", output
    end
  end

  test "upgrade rolling" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("12345678")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :cut, "-d:", "-f2")
      .returns(Kamal::Configuration::Proxy::MINIMUM_VERSION)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    run_command("upgrade", "--rolling", "-y",).tap do |output|
      %w[1.1.1.1 1.1.1.2 1.1.1.3 1.1.1.4].each do |host|
        assert_match "Upgrading proxy on #{host}...", output
        assert_match "docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik on #{host}", output
        assert_match "Upgraded proxy on #{host}", output
      end
    end
  end

  private
    def run_command(*command, fixture: :with_proxy)
      stdouted { Kamal::Cli::Proxy.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end
end
