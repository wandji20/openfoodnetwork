angular.module("admin.products")
  .controller "unitsCtrl", ($scope, VariantUnitManager, OptionValueNamer, UnitPrices, localizeCurrencyFilter) ->
    $scope.product = { master: {} }
    $scope.product.master.product = $scope.product
    $scope.placeholder_text = ""

    $scope.$watchCollection '[product.variant_unit_with_scale, product.master.unit_value_with_description, product.price, product.variant_unit_name]', ->
      $scope.processVariantUnitWithScale()
      $scope.processUnitValueWithDescription()
      $scope.processUnitPrice()
      $scope.placeholder_text = new OptionValueNamer($scope.product.master).name()

    $scope.variant_unit_options = VariantUnitManager.variantUnitOptions()

    $scope.processVariantUnitWithScale = ->
      if $scope.product.variant_unit_with_scale
        match = $scope.product.variant_unit_with_scale.match(/^([^_]+)_([\d\.]+)$/)
        if match
          $scope.product.variant_unit = match[1]
          $scope.product.variant_unit_scale = parseFloat(match[2])
        else
          $scope.product.variant_unit = $scope.product.variant_unit_with_scale
          $scope.product.variant_unit_scale = null
      else
        $scope.product.variant_unit = $scope.product.variant_unit_scale = null

    $scope.processUnitValueWithDescription = ->
      if $scope.product.master.hasOwnProperty("unit_value_with_description")
        match = $scope.product.master.unit_value_with_description.match(/^([\d\.]+(?= *|$)|)( *)(.*)$/)
        if match
          $scope.product.master.unit_value  = parseFloat(match[1])
          $scope.product.master.unit_value  = null if isNaN($scope.product.master.unit_value)
          $scope.product.master.unit_value *= $scope.product.variant_unit_scale if $scope.product.master.unit_value && $scope.product.variant_unit_scale
          $scope.product.master.unit_description = match[3]

    $scope.processUnitPrice = ->
      price = $scope.product.price
      scale = $scope.product.variant_unit_scale
      unit_type = $scope.product.variant_unit
      unit_value = $scope.product.master.unit_value
      variant_unit_name = $scope.product.variant_unit_name
      $scope.product.unit_price_value = null
      $scope.product.unit_price_unit = null
      if price && unit_type && unit_value
        $scope.product.unit_price_value = localizeCurrencyFilter(UnitPrices.price(price, scale, unit_type, unit_value, variant_unit_name))
        $scope.product.unit_price_unit = UnitPrices.unit(scale, unit_type, variant_unit_name)

    $scope.hasVariants = (product) ->
      Object.keys(product.variants).length > 0

    $scope.hasUnit = (product) ->
      product.variant_unit_with_scale?
