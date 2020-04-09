$(document).ready(function(e) {

  //lead scroll down
  $(".scroll-down").click(function() {
    $('html, body').animate({scrollTop: $("#regions").offset().top},'slow');
  });

  //data scroll
  $(".composition-nav-link").click(function() {
    $('html, body').animate({scrollTop: $("#composition").offset().top},'slow');
  });
  $(".regions-nav-link").click(function() {
    $('html, body').animate({scrollTop: $("#regions").offset().top},'slow');
  });
  $(".visualisations-nav-link").click(function() {
    $('html, body').animate({scrollTop: $("#visualisations").offset().top},'slow');
  });
  
  //team scroll
  $(".team-nav-link").click(function() {
    $('html, body').animate({scrollTop: $("#team").offset().top},'slow');
  });

  //partners scroll
  $(".partners-nav-link").click(function() {
    $('html, body').animate({scrollTop: $("#partners").offset().top},'slow');
  });
    

  //heart reagions image map
  $('img[usemap]').rwdImageMaps();


});

const $dropdown = $(".dropdown");
const $dropdownToggle = $(".dropdown-toggle");
const $dropdownMenu = $(".dropdown-menu");
const showClass = "show";
$(window).on("load resize", function() {
  if (this.matchMedia("(min-width: 768px)").matches) {
    $dropdown.hover(
      function() {
        const $this = $(this);
        $this.addClass(showClass);
        $this.find($dropdownToggle).attr("aria-expanded", "true");
        $this.find($dropdownMenu).addClass(showClass);
      },
      function() {
        const $this = $(this);
        $this.removeClass(showClass);
        $this.find($dropdownToggle).attr("aria-expanded", "false");
        $this.find($dropdownMenu).removeClass(showClass);
      }
    );
  } else {
    $dropdown.off("mouseenter mouseleave");
  }
});

