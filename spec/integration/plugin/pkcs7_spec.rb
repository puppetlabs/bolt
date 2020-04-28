# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/integration'

describe 'using the pkcs7 plugin' do
  include BoltSpec::Integration

  def with_boltdir(config: nil, inventory: nil)
    Dir.mktmpdir do |tmpdir|
      File.write(File.join(tmpdir, 'bolt.yaml'), config.to_yaml) if config
      File.write(File.join(tmpdir, 'inventory.yaml'), inventory.to_yaml) if inventory
      yield tmpdir
    end
  end

  let(:private_key) {
    <<~PRIVATE
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAq2nH4zn/Ls0iqM/S77xvg5umtBvsBbeV+VPgBT2LYSxAwuQi
      wlMd0gng9AHU7rcv6CRVPV1blv8+ZbvJw8TyJGkrUHjQPTgwDBFxrs4iZhA90Yxm
      WvzCGr9i2200Qx2MVALu7mwhagpQVKO88BXRs0mJ4+lxwTSiXFFyvQydujrn9Jgl
      4snm6VSyxZrB9EsSoHOj013kzZ4YpwWVoGY6yz8chiOjGWgjNKArPrpxdwZYLdgW
      wk2nhSYK8HAJIXokkQGlkS9ykN6OwwrP9V6M/sF4uejCmWys0awgZpFWa7uxkl9D
      /6YeF6GnqiC2Ge8qBYwBuKOX4/NEuxVMsoTn0QIDAQABAoIBAAqLDBdm1tJLHcmi
      VsgWIAnJRhyn5wGHBDt8tDe+TFdiwGz8WUL4l8n2f5aikjVIoTK3IWMP3fVQp8bc
      IRHgiEBDE730YGKTlSj43bQxy53Ze+PqrdUE3O+GPA9hDSjfpWT5dTbHAdsi3UQH
      ejSOMwLDEC8riaqnkSD6hYMpRn5QzWfur4l44X0Y16APtU4xt1joNnCZ8alkwwFI
      v+KpmIDhDsloy08BZFVHPQHt+fT2JQagLs+y0+dzamAQz/rEj2kCpv7rNXDqjgPz
      qzuZp+uqnK63sylnFx460WsSFFaslhTxSV+zeIayncM7jSCZ/nkFmmTlOd1BBr2L
      j/WDR8ECgYEA3uCMkv2OEp7CHW2j9ZwDS0SGFVzGoeobREB961yiBekSv13mkgiL
      dkScpdUs1BPBHGql1E3S1QJccADhMK9LkNfxy2kchw6S+PQHp7y8Jc+NbMfOKSW0
      szpAd0e2rFfWsyBevsdw4X9aDaBAdcQrM02zYhKVDc4jPbAuIEuOsGkCgYEAxOND
      8F5xjzI6Y38ADAykJfI3I9humX3vZxnDu5OAbuZEApC8Sm0YKS4GTB4bXxcuf5p5
      fNOCqLR+bEpcvCXwM3jqQVIKIg3ivPX2cZ6CC2UmsBetHp8UF3u8NfzozPWK5E9d
      65hOHglxCwdQ0+rfxoPD1ITdx9kK5ky9zD8gjykCgYBVGQmzigp4A5P8ZoOG4NXF
      JFnJyE2zPs7AZZtuhUT72r0kwjaqJYcSVio1i0p9gzllnzbH9Br+59LhlQRmcVf5
      6unQj8arrp3hXlOZ8Q8ppLDMCxIlVddD44b/xCr0bOl2JXLnhwELqHN65mgWTxtr
      kExgstWkmsOL5zwFarQFmQKBgCcY0ibrOjWrTbjwQTwjTn1SieyOT/ge7+lTTnDz
      K2/aPescfqdw3nle8FUxLVJGsi8Yp8NH5QxHO0uZwKyEBBzUiAAMoIJ+q2XGmfeZ
      +Ez2+yXArdoE0OKQ6aD25eu9XqVTtVzRU8HXMiF0hHJwk5tCEyMidz/2M5nj51Sl
      vHtxAoGBAICQHpOBrEXD1P1P3t/R4y0pQeatVIkNZwSSnzZ1t4/1BUkQKIAvuUCC
      PvVi9WF8YGBWq7VZbVx4FDdXlHYAD36P13ivGfbOqc8ew21Gtu5XzdmUSL8ITkWl
      Svvug1jXsghTzHXuj2A5cQBm4QMMPmncBzFgDg4yArjYZd/LVEpD
      -----END RSA PRIVATE KEY-----
    PRIVATE
  }

  let(:public_key) {
    <<~PUBLIC
      -----BEGIN CERTIFICATE-----
      MIICezCCAWOgAwIBAgIBATANBgkqhkiG9w0BAQ0FADAAMCAXDTE5MDYxNzE4MzIz
      MloYDzIwNjkwNjA0MTgzMjMyWjAAMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
      CgKCAQEAq2nH4zn/Ls0iqM/S77xvg5umtBvsBbeV+VPgBT2LYSxAwuQiwlMd0gng
      9AHU7rcv6CRVPV1blv8+ZbvJw8TyJGkrUHjQPTgwDBFxrs4iZhA90YxmWvzCGr9i
      2200Qx2MVALu7mwhagpQVKO88BXRs0mJ4+lxwTSiXFFyvQydujrn9Jgl4snm6VSy
      xZrB9EsSoHOj013kzZ4YpwWVoGY6yz8chiOjGWgjNKArPrpxdwZYLdgWwk2nhSYK
      8HAJIXokkQGlkS9ykN6OwwrP9V6M/sF4uejCmWys0awgZpFWa7uxkl9D/6YeF6Gn
      qiC2Ge8qBYwBuKOX4/NEuxVMsoTn0QIDAQABMA0GCSqGSIb3DQEBDQUAA4IBAQBx
      O+nJBTdyIMQff6x2w+RT5bmaaQPqW5nEE4fut/ihU5FLxxINj+XsIwCJhZmag1Jj
      iiQ8nYW9w4zhpHjMHdUTYLAwizEZ6eDdyfO8NavrUV00oeq8jND6TgZZZBAXtWJ2
      x1Se6hLROI5f5DVeFMqDoAwg3N67EVGAvXni59033hATTNMbAPYmU6At/xfUH3i6
      ZZFiNxu0gY9s+blWagpP734NCT7XBlCqnI++j5cbOdLS9s3+p9/XZZi4gHJakndE
      HUa41hPpf1R4+kGVOG3IN/wHYnXfCUyW1IQpBnEaDvqTk9M08pCqjF5cmhriscSK
      YtrOSLrPrTvNC/p/5KfG
      -----END CERTIFICATE-----
    PUBLIC
  }

  let(:config) {
    { 'plugins' => {
      'pkcs7' => {
        'private-key' => 'private',
        'public-key' => 'public'
      }
    } }
  }

  let(:encrypted_ssshhh) {
    <<~SHHHH
      ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw
      DQYJKoZIhvcNAQEBBQAEggEAdCVkiddtK8jHz4g1y1pkB27VHCZx7dVzEiyT
      33BgFv9atk8Ns/WE1tveFvyuEaDpk9y/FKisuh8DsTnR2mfGvHtX+BQdNqV6
      L8/nIdwoEqYFd5sKFJnOlpdm7BMX4QDoCfGb+b2UB8A/7eJJ5AcgBVtrJLLE
      VvqSCtqME12ltifdMivMP1hnVJOAhIpib8CwOIIP+Dtv7P7cPaHGTdQpR6Dp
      jbe+AUDM6kcKGADLOYriPQ1UV6zDz5aeUbrwbr4FicHL/sQBPDcWIJR2elwY
      bh8hCDe/IIWE7TOiauXOPyMPKohz622KNoJDJbmv5MhBwNFHSjgKAlOAxL3i
      DK7XXzA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBCvjDMKTjsHloKP04WO
      Dq0ogBAUjTZMjbKjkndMSqPC5mGC]
    SHHHH
  }

  it 'uses the configured key files' do
    with_boltdir(config: config) do |project|
      run_cli(['secret', 'createkeys', '--boltdir', project])
      expect(File.exist?(File.join(project, 'private'))).to eq(true)
      expect(File.exist?(File.join(project, 'public'))).to eq(true)
    end
  end

  it 'errors with an unexpected key' do
    with_boltdir(config: { 'plugins' => { 'pkcs7' => { 'public_key' => '/path' } } }) do |project|
      expect { run_cli(['secret', 'createkeys', '--boltdir', project]) }.to raise_error(Bolt::ValidationError)
    end
  end

  it 'encrypts a value' do
    with_boltdir(config: config) do |project|
      File.write(File.join(project, 'public'), public_key)
      File.write(File.join(project, 'private'), private_key)
      output = run_cli(['secret', 'encrypt', 'ssshhh', '--boltdir', project], outputter: Bolt::Outputter::Human)
      expect(output).to start_with('ENC[PKCS7,')
      decrypt = run_cli(['secret', 'decrypt', output, '--boltdir', project], outputter: Bolt::Outputter::Human)
      expect(decrypt.strip).to eq('ssshhh')
    end
  end

  it 'decrypts a value' do
    with_boltdir(config: config) do |project|
      File.write(File.join(project, 'public'), public_key)
      File.write(File.join(project, 'private'), private_key)
      output = run_cli(['secret', 'decrypt', encrypted_ssshhh, '--boltdir', project],
                       outputter: Bolt::Outputter::Human)
      expect(output.strip).to eq('ssshhh')
    end
  end

  it 'decrypts an inventory file' do
    inventory = { 'targets' => [
      { 'uri' => 'node1',
        'config' => {
          'ssh' => {
            'user' => 'me',
            'password' => {
              '_plugin' => 'pkcs7',
              'encrypted_value' => encrypted_ssshhh
            }
          }
        } }
    ] }
    plan = <<~PLAN
      plan passw() {
        return(get_targets('node1')[0].password)
      }
    PLAN
    with_boltdir(inventory: inventory, config: config) do |project|
      plan_dir = File.join(project, 'modules', 'passw', 'plans')
      FileUtils.mkdir_p(plan_dir)
      File.write(File.join(plan_dir, 'init.pp'), plan)
      File.write(File.join(project, 'public'), public_key)
      File.write(File.join(project, 'private'), private_key)
      output = run_cli(['plan', 'run', 'passw', '--boltdir', project])

      expect(output.strip).to eq('"ssshhh"')
    end
  end
end
