require 'date'

module DuckDB
  if defined?(DuckDB::Appender)
    # The DuckDB::Appender encapsulates DuckDB Appender.
    #
    #   require 'duckdb'
    #   db = DuckDB::Database.open
    #   con = db.connect
    #   con.query('CREATE TABLE users (id INTEGER, name VARCHAR)')
    #   appender = con.appender('users')
    #   appender.append_row(1, 'Alice')
    #
    class Appender
      RANGE_INT16 = -32_768..32_767
      RANGE_INT32 = -2_147_483_648..2_147_483_647
      RANGE_INT64 = -9_223_372_036_854_775_808..9_223_372_036_854_775_807

      #
      # appends huge int value.
      #
      #   require 'duckdb'
      #   db = DuckDB::Database.open
      #   con = db.connect
      #   con.query('CREATE TABLE numbers (num HUGEINT)')
      #   appender = con.appender('numbers')
      #   appender
      #     .begin_row
      #     .append_hugeint(-170_141_183_460_469_231_731_687_303_715_884_105_727)
      #     .end_row
      #
      def append_hugeint(value)
        case value
        when Integer
          if respond_to?(:_append_hugeint, true)
            half = 1 << 64
            upper = value / half
            lower = value - upper * half
            _append_hugeint(lower, upper)
          else
            append_varchar(value.to_s)
          end
        else
          raise(ArgumentError, "2nd argument `#{value}` must be Integer.")
        end
      end

      #
      # appends date value.
      #
      #   require 'date'
      #   require 'duckdb'
      #   db = DuckDB::Database.open
      #   con = db.connect
      #   con.query('CREATE TABLE dates (date_value DATE)')
      #   appender = con.appender('dates')
      #   appender.begin_row
      #   appender.append_date(Date.today)
      ##  or
      ##  appender.append_date(Time.now)
      ##  appender.append_date('2021-10-10')
      #   appender.end_row
      #   appender.flush
      #
      def append_date(value)
        case value
        when Date, Time
          date = value
        when String
          begin
            date = Date.parse(value)
          rescue
            raise(ArgumentError, "Cannot parse 2nd argument `#{value}` to Date.")
          end
        else
          raise(ArgumentError, "2nd argument `#{value}` must be Date, Time or String.")
        end

        _append_date(date.year, date.month, date.day)
      end

      #
      # appends value.
      #
      #   require 'duckdb'
      #   db = DuckDB::Database.open
      #   con = db.connect
      #   con.query('CREATE TABLE users (id INTEGER, name VARCHAR)')
      #   appender = con.appender('users')
      #   appender.begin_row
      #   appender.append(1)
      #   appender.append('Alice')
      #   appender.end_row
      #
      def append(value)
        case value
        when NilClass
          append_null
        when Float
          append_double(value)
        when Integer
          case value
          when RANGE_INT16
            append_int16(value)
          when RANGE_INT32
            append_int32(value)
          when RANGE_INT64
            append_int64(value)
          else
            append_hugeint(value)
          end
        when String
          if defined?(DuckDB::Blob)
            blob?(value) ? append_blob(value) : append_varchar(value)
          else
            append_varchar(value)
          end
        when TrueClass, FalseClass
          append_bool(value)
        when Time
          append_varchar(value.strftime('%Y-%m-%d %H:%M:%S.%N'))
        when Date
          append_varchar(value.strftime('%Y-%m-%d'))
        else
          raise(DuckDB::Error, "not supported type #{value} (#{value.class})")
        end
      end

      #
      # append a row.
      #
      #   appender.append_row(1, 'Alice')
      #
      # is same as:
      #
      #   appender.begin_row
      #   appender.append(1)
      #   appender.append('Alice')
      #   appender.end_row
      #
      def append_row(*args)
        begin_row
        args.each do |arg|
          append(arg)
        end
        end_row
      end

      private

      def blob?(value)
        value.instance_of?(DuckDB::Blob) || value.encoding == Encoding::BINARY
      end
    end
  end
end
