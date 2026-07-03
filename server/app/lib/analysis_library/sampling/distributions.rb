# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Pure-Ruby quantile functions and LHS strata generation. This is the non-R
# backend for sampling algorithms; the formulas intentionally replicate the R
# implementations in analysis_library/r/lhs.rb (lhs::randomLHS, qnorm, qlnorm,
# qunif, triangle::qtriangle, e1071::qdiscrete) so both backends produce
# statistically equivalent designs.
module AnalysisLibrary::Sampling
  module Distributions
    module_function

    # Latin hypercube probabilities equivalent to lhs::randomLHS(sample_size, num_variables).
    # For each variable the [0,1) interval is split into sample_size strata; each stratum is
    # hit exactly once, at a uniform random point, in shuffled order.
    #
    # @return [Hash] column index => array of probabilities (same shape as R::Lhs#lhs_probability)
    def lhs_probability(num_variables, sample_size, rng = Random.new)
      o = {}
      (0...num_variables).each do |col|
        strata = (0...sample_size).to_a.shuffle(random: rng)
        o[col] = strata.map { |s| (s + rng.rand) / sample_size.to_f }
      end
      o
    end

    # Inverse standard normal CDF using Peter Acklam's rational approximation,
    # refined with one Halley step against Math.erfc for near double precision.
    def inverse_normal_cdf(p)
      raise "probability #{p} out of (0,1) for inverse_normal_cdf" if p <= 0.0 || p >= 1.0

      a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
           1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
      b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
           6.680131188771972e+01, -1.328068155288572e+01]
      c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
           -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
      d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
           3.754408661907416e+00]

      p_low = 0.02425
      p_high = 1.0 - p_low

      x = if p < p_low
            q = Math.sqrt(-2.0 * Math.log(p))
            (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
              ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
          elsif p <= p_high
            q = p - 0.5
            r = q * q
            (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
              (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0)
          else
            q = Math.sqrt(-2.0 * Math.log(1.0 - p))
            -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
              ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
          end

      # Halley refinement
      e = 0.5 * Math.erfc(-x / Math.sqrt(2.0)) - p
      u = e * Math.sqrt(2.0 * Math::PI) * Math.exp(x * x / 2.0)
      x - u / (1.0 + x * u / 2.0)
    end

    # qunif
    def q_uniform(p, min, max)
      min + p * (max - min)
    end

    # qnorm(p, mean, sd)
    def q_normal(p, mean, stddev)
      mean + stddev * inverse_normal_cdf(p)
    end

    # Replicates the R lognormal block in r/lhs.rb verbatim:
    #   sigma <- sqrt(log(stddev/(mean^2)+1)); mu <- log((mean^2)/sqrt(stddev+mean^2))
    # NOTE: this treats 'stddev' as a variance-like quantity. It is intentionally
    # kept identical to the R backend rather than corrected, so both backends match.
    def q_lognormal(p, mean, stddev)
      sigma = Math.sqrt(Math.log(stddev / (mean**2) + 1.0))
      mu = Math.log((mean**2) / Math.sqrt(stddev + mean**2))
      Math.exp(mu + sigma * inverse_normal_cdf(p))
    end

    # triangle::qtriangle(p, min, max, mode)
    def q_triangle(p, min, max, mode)
      raise "invalid triangle bounds min=#{min} max=#{max} mode=#{mode}" unless min <= mode && mode <= max && min < max

      f_mode = (mode - min) / (max - min).to_f
      if p <= f_mode
        min + Math.sqrt(p * (max - min) * (mode - min))
      else
        max - Math.sqrt((1.0 - p) * (max - min) * (max - mode))
      end
    end

    # e1071::qdiscrete equivalent: inverse CDF over the given values with the
    # given (not necessarily normalized) weights. Returns the first value whose
    # cumulative probability reaches p.
    def q_discrete(p, weights, values)
      raise 'weights and values must be the same length' unless weights.size == values.size
      raise 'no discrete values passed' if values.empty?

      total = weights.sum.to_f
      raise 'discrete weights sum to zero' if total <= 0.0

      cumulative = 0.0
      weights.each_with_index do |w, i|
        cumulative += w / total
        return values[i] if p <= cumulative
      end
      values.last # guard against floating point round-off at p ~ 1.0
    end

    # Replicates R seq(from, to, by) used for integer_sequence variables/pivots.
    def seq(from, to, by)
      by = 1 if by.nil? || by.to_f.zero?
      from.to_f.step(to.to_f, by.to_f).to_a
    end
  end
end
