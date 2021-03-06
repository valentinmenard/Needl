$(document).ready(function(){
  if ($('.restaurants-autocomplete').length) {
    var input = $('.restaurants-autocomplete');

    var restaurants = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: $(input).data("url") + '/autocomplete.json?query=%QUERY',
        wildcard: '%QUERY'
      }
    });

    $('.restaurants-autocomplete').typeahead(null, {
      name: 'best-pictures',
      displayKey: 'name_and_address',
      minLength: 1,
      source: restaurants
    }).on('typeahead:selected', function($e, restaurant) {
      $(".restaurants-autocomplete--id").val(restaurant.id);
      $(".restaurants-autocomplete--origin").val(restaurant.origin);
      $("#restaurant_name").css({
        "border": "3px solid #38E1B2"
      });
      var $checker = $("<span class='check'><i class='fa fa-check'></i></span>");
      $checker.insertAfter("#restaurant_name");
    });
  }
});