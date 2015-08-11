def expect_log(text, level = :info, logger = Itrp.configuration.logger)
  expect(logger).to receive(level).ordered { |&args| expect(args.call).to eq(text) }
end