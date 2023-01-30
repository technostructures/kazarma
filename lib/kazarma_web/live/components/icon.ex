# SPDX-FileCopyrightText: 2020-2022 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Components.Icon do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML

  @doc """
  Search icon

  Set: Feather
  License: MIT
  """
  def search_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="feather feather-search"
    >
      <circle cx="11" cy="11" r="8"></circle>
      <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
    </svg>
    """
  end

  @doc """
  GitLab icon

  Set: Feather
  License: MIT
  """
  def gitlab_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="feather feather-gitlab"
    >
      <path d="M22.65 14.39L12 22.13 1.35 14.39a.84.84 0 0 1-.3-.94l1.22-3.78 2.44-7.51A.42.42 0 0 1 4.82 2a.43.43 0 0 1 .58 0 .42.42 0 0 1 .11.18l2.44 7.49h8.1l2.44-7.51A.42.42 0 0 1 18.6 2a.43.43 0 0 1 .58 0 .42.42 0 0 1 .11.18l2.44 7.51L23 13.45a.84.84 0 0 1-.35.94z">
      </path>
    </svg>
    """
  end

  @doc """
  Copy icon

  Set: Feather
  License: MIT
  """
  def copy_icon(assigns) do
    ~H"""
    <svg
      style="display: inline"
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="feather feather-copy"
    >
      <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
    </svg>
    """
  end

  @doc """
  External link icon

  Set: Feather
  License: MIT
  """
  def external_link_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="feather feather-external-link"
    >
      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path>
      <polyline points="15 3 21 3 21 9"></polyline>
      <line x1="10" y1="14" x2="21" y2="3"></line>
    </svg>
    """
  end

  def reply_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      preserveAspectRatio="xMidYMid meet"
      viewBox="0 0 16 16"
      class={@class}
    >
      <path
        fill="currentColor"
        d="M9.402 10.987C9.37991 10.9967 9.35573 11.0007 9.33168 10.9987C9.30763 10.9966 9.28449 10.9885 9.26438 10.9752C9.24426 10.9619 9.22783 10.9437 9.21658 10.9223C9.20533 10.901 9.19963 10.8771 9.2 10.853V9.69999C9.2 9.56739 9.14732 9.44021 9.05355 9.34644C8.95978 9.25267 8.8326 9.19999 8.7 9.19999C8.033 9.19999 6.687 9.19499 5.4 8.37799C4.416 7.75399 3.41 6.618 2.805 4.502C3.825 5.485 4.99 6.01799 6.01 6.30099C6.63695 6.47416 7.28127 6.57679 7.931 6.607C8.19695 6.61868 8.46333 6.61601 8.729 6.599H8.742L8.747 6.59799L8.7 6.1L8.75 6.59799C8.87341 6.58559 8.98781 6.52776 9.07098 6.43572C9.15414 6.34369 9.20012 6.22403 9.2 6.1V4.94699C9.2 4.83899 9.31 4.77099 9.402 4.81299L13.386 7.746C13.3995 7.75603 13.4135 7.76537 13.428 7.774C13.4497 7.78706 13.4677 7.80553 13.4802 7.82761C13.4927 7.84969 13.4993 7.87463 13.4993 7.89999C13.4993 7.92536 13.4927 7.9503 13.4802 7.97238C13.4677 7.99446 13.4497 8.01293 13.428 8.026C13.4135 8.03461 13.3995 8.04396 13.386 8.05399L9.402 10.987ZM8.2 5.614C8.132 5.614 8.057 5.611 7.977 5.608C7.543 5.588 6.943 5.522 6.277 5.337C4.951 4.969 3.381 4.135 2.337 2.257C2.28054 2.15562 2.19058 2.07704 2.08254 2.03472C1.9745 1.9924 1.8551 1.98897 1.74481 2.02502C1.63452 2.06108 1.5402 2.13437 1.47802 2.23234C1.41584 2.3303 1.38967 2.44685 1.404 2.562C1.868 6.272 3.29 8.224 4.864 9.222C6.109 10.012 7.391 10.164 8.2 10.193V10.853C8.1999 11.0589 8.2554 11.2611 8.36063 11.4381C8.46585 11.6151 8.61691 11.7604 8.79786 11.8587C8.97881 11.957 9.18295 12.0047 9.38872 11.9966C9.59449 11.9886 9.79428 11.9251 9.967 11.813L13.961 8.873C14.1261 8.76993 14.2623 8.62653 14.3567 8.45631C14.4511 8.28609 14.5006 8.09464 14.5006 7.89999C14.5006 7.70535 14.4511 7.5139 14.3567 7.34368C14.2623 7.17346 14.1261 7.03006 13.961 6.927L9.967 3.987C9.79428 3.87485 9.59449 3.8114 9.38872 3.80335C9.18295 3.7953 8.97881 3.84294 8.79786 3.94125C8.61691 4.03956 8.46585 4.18489 8.36063 4.36191C8.2554 4.53893 8.1999 4.74106 8.2 4.94699V5.614Z"
      />
    </svg>
    """
  end

  def replied_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      preserveAspectRatio="xMidYMid meet"
      viewBox="0 0 16 16"
      class={@class}
    >
      <path
        fill="currentColor"
        d="M6.598 5.013a.144.144 0 0 1 .202.134V6.3a.5.5 0 0 0 .5.5c.667 0 2.013.005 3.3.822c.984.624 1.99 1.76 2.595 3.876c-1.02-.983-2.185-1.516-3.205-1.799a8.74 8.74 0 0 0-1.921-.306a7.404 7.404 0 0 0-.798.008h-.013l-.005.001h-.001L7.3 9.9l-.05-.498a.5.5 0 0 0-.45.498v1.153c0 .108-.11.176-.202.134L2.614 8.254a.503.503 0 0 0-.042-.028a.147.147 0 0 1 0-.252a.499.499 0 0 0 .042-.028l3.984-2.933zM7.8 10.386c.068 0 .143.003.223.006c.434.02 1.034.086 1.7.271c1.326.368 2.896 1.202 3.94 3.08a.5.5 0 0 0 .933-.305c-.464-3.71-1.886-5.662-3.46-6.66c-1.245-.79-2.527-.942-3.336-.971v-.66a1.144 1.144 0 0 0-1.767-.96l-3.994 2.94a1.147 1.147 0 0 0 0 1.946l3.994 2.94a1.144 1.144 0 0 0 1.767-.96v-.667z"
      />
    </svg>
    """
  end

  @doc """
  Alert icon

  Set: DaisyUI
  """
  def alert_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="stroke-current flex-shrink-0 h-6 w-6"
      fill="none"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  @doc """
  Help icon

  Set: IonIcons
  Author: Ben Sperry
  License: MIT
  """
  def help_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="1em"
      height="1em"
      preserveAspectRatio="xMidYMid meet"
      viewBox="0 0 512 512"
    >
      <path
        fill="none"
        stroke="currentColor"
        stroke-miterlimit="10"
        stroke-width="32"
        d="M256 80a176 176 0 1 0 176 176A176 176 0 0 0 256 80Z"
      /><path
        fill="none"
        stroke="currentColor"
        stroke-linecap="round"
        stroke-miterlimit="10"
        stroke-width="28"
        d="M200 202.29s.84-17.5 19.57-32.57C230.68 160.77 244 158.18 256 158c10.93-.14 20.69 1.67 26.53 4.45c10 4.76 29.47 16.38 29.47 41.09c0 26-17 37.81-36.37 50.8S251 281.43 251 296"
      /><circle cx="250" cy="348" r="20" fill="currentColor" />
    </svg>
    """
  end

  @doc """
  Matrix icon

  Source: https://commons.wikimedia.org/wiki/File:Matrix_icon.svg
  License: Public domain
  """
  def matrix_icon(assigns) do
    ~H"""
    <svg
      version="1.1"
      viewBox="0 0 27.9 32"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:cc="http://creativecommons.org/ns#"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    >
      <title>Matrix (protocol) logo</title>
      <g transform="translate(-.095 .005)" fill="#040404">
        <path d="m27.1 31.2v-30.5h-2.19v-0.732h3.04v32h-3.04v-0.732z" />
        <path d="m8.23 10.4v1.54h0.044c0.385-0.564 0.893-1.03 1.49-1.37 0.58-0.323 1.25-0.485 1.99-0.485 0.72 0 1.38 0.14 1.97 0.42 0.595 0.279 1.05 0.771 1.36 1.48 0.338-0.5 0.796-0.941 1.38-1.32 0.58-0.383 1.27-0.574 2.06-0.574 0.602 0 1.16 0.074 1.67 0.22 0.514 0.148 0.954 0.383 1.32 0.707 0.366 0.323 0.653 0.746 0.859 1.27 0.205 0.522 0.308 1.15 0.308 1.89v7.63h-3.13v-6.46c0-0.383-0.015-0.743-0.044-1.08-0.0209-0.307-0.103-0.607-0.242-0.882-0.133-0.251-0.336-0.458-0.584-0.596-0.257-0.146-0.606-0.22-1.05-0.22-0.44 0-0.796 0.085-1.07 0.253-0.272 0.17-0.485 0.39-0.639 0.662-0.159 0.287-0.264 0.602-0.308 0.927-0.052 0.347-0.078 0.697-0.078 1.05v6.35h-3.13v-6.4c0-0.338-7e-3 -0.673-0.021-1-0.0114-0.314-0.0749-0.623-0.188-0.916-0.108-0.277-0.3-0.512-0.55-0.673-0.258-0.168-0.636-0.253-1.14-0.253-0.198 0.0083-0.394 0.042-0.584 0.1-0.258 0.0745-0.498 0.202-0.705 0.374-0.228 0.184-0.422 0.449-0.584 0.794-0.161 0.346-0.242 0.798-0.242 1.36v6.62h-3.13v-11.4z" />
        <path d="m0.936 0.732v30.5h2.19v0.732h-3.04v-32h3.03v0.732z" />
      </g>
      <style xmlns="" data-source="base" class="dblt-ykjmwcnxmi" /><style
        xmlns=""
        data-source="stylesheet-processor"
        class="dblt-ykjmwcnxmi"
      />
      <div xmlns="" id="saka-gui-root">
        <div>
          <div><style /></div>
        </div>
      </div>
    </svg>
    """
  end

  @doc """
  ActivityPub icon

  Source: https://commons.wikimedia.org/wiki/File:ActivityPub-logo-symbol.svg
  License: Public domain
  """
  def ap_icon(assigns) do
    ~H"""
    <svg
      xmlns:osb="http://www.openswatchbook.org/uri/2009/osb"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:cc="http://creativecommons.org/ns#"
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:svg="http://www.w3.org/2000/svg"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
      xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
      width="130"
      height="130"
      viewBox="0 0 34.395832 34.395832"
      version="1.1"
      id="svg8"
      inkscape:version="0.92.1 r15371"
      sodipodi:docname="ActivityPub-logo-symbol.svg"
    >
      <title id="title4590">ActivityPub logo</title>
      <defs id="defs2">
        <linearGradient id="AP-4-0" osb:paint="solid">
          <stop style="stop-color:#5e5e5e;stop-opacity:1;" offset="0" id="stop5660" />
        </linearGradient>
        <linearGradient id="linearGradient5640" osb:paint="solid">
          <stop style="stop-color:#000000;stop-opacity:1;" offset="0" id="stop5638" />
        </linearGradient>
        <linearGradient id="linearGradient5634" osb:paint="solid">
          <stop style="stop-color:#000000;stop-opacity:1;" offset="0" id="stop5632" />
        </linearGradient>
        <linearGradient id="linearGradient5628" osb:paint="solid">
          <stop style="stop-color:#000000;stop-opacity:1;" offset="0" id="stop5626" />
        </linearGradient>
        <linearGradient id="AP-3-7" osb:paint="solid">
          <stop style="stop-color:#c678c5;stop-opacity:1;" offset="0" id="stop5498" />
        </linearGradient>
        <linearGradient id="AP-2-3" osb:paint="solid">
          <stop style="stop-color:#6d6d6d;stop-opacity:1;" offset="0" id="stop5230" />
        </linearGradient>
        <linearGradient id="AP1-5" osb:paint="solid">
          <stop style="stop-color:#f1007e;stop-opacity:1;" offset="0" id="stop5212" />
        </linearGradient>
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP-3-7"
          id="linearGradient5749"
          gradientUnits="userSpaceOnUse"
          x1="3319.292"
          y1="-1291.2802"
          x2="3344.3645"
          y2="-1291.2802"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP1-5"
          id="linearGradient7297-7"
          gradientUnits="userSpaceOnUse"
          x1="3241.6836"
          y1="-1355.4329"
          x2="3254.9529"
          y2="-1355.4329"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP-2-3"
          id="linearGradient7303-7"
          gradientUnits="userSpaceOnUse"
          x1="3225.7603"
          y1="-1355.4329"
          x2="3239.0295"
          y2="-1355.4329"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP1-5"
          id="linearGradient8308"
          gradientUnits="userSpaceOnUse"
          x1="3241.6836"
          y1="-1355.4329"
          x2="3254.9529"
          y2="-1355.4329"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP1-5"
          id="linearGradient8310"
          gradientUnits="userSpaceOnUse"
          x1="3241.6836"
          y1="-1355.4329"
          x2="3254.9529"
          y2="-1355.4329"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP1-5"
          id="linearGradient8312"
          gradientUnits="userSpaceOnUse"
          x1="3241.6836"
          y1="-1355.4329"
          x2="3254.9529"
          y2="-1355.4329"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP-2-3"
          id="linearGradient8314"
          gradientUnits="userSpaceOnUse"
          x1="3225.7603"
          y1="-1355.4329"
          x2="3239.0295"
          y2="-1355.4329"
          gradientTransform="matrix(3.7000834,0,0,3.7000834,-11935.582,4544.6634)"
        />
        <linearGradient
          inkscape:collect="always"
          xlink:href="#AP-2-3"
          id="linearGradient5188"
          gradientUnits="userSpaceOnUse"
          gradientTransform="matrix(0.42732603,0,0,0.42732603,-1363.3009,454.91899)"
          x1="3269.126"
          y1="-1354.6217"
          x2="3322.1943"
          y2="-1354.6217"
        />
      </defs>
      <sodipodi:namedview
        id="base"
        pagecolor="#ffffff"
        bordercolor="#666666"
        borderopacity="0.14509804"
        inkscape:pageopacity="0.0"
        inkscape:pageshadow="2"
        inkscape:zoom="0.70710678"
        inkscape:cx="-195.34129"
        inkscape:cy="-120.65903"
        inkscape:document-units="px"
        inkscape:current-layer="layer1"
        showgrid="false"
        inkscape:snap-global="true"
        showguides="false"
        inkscape:guide-bbox="true"
        showborder="true"
        fit-margin-top="0"
        fit-margin-left="0"
        fit-margin-right="0"
        fit-margin-bottom="0"
        inkscape:showpageshadow="false"
        borderlayer="false"
        units="px"
      >
        <inkscape:grid
          type="xygrid"
          id="grid4572"
          enabled="false"
          originx="7.1437514"
          originy="-404.28382"
        />
        <inkscape:grid
          type="axonomgrid"
          id="grid4574"
          units="mm"
          empspacing="12"
          originx="7.1437514"
          originy="-404.28382"
          enabled="false"
        />
        <sodipodi:guide
          position="3278.981,1256.5057"
          orientation="0,1"
          id="guide5059"
          inkscape:locked="false"
        />
        <sodipodi:guide
          position="3278.981,1238.2495"
          orientation="0,1"
          id="guide5061"
          inkscape:locked="false"
        />
      </sodipodi:namedview>
      <metadata id="metadata5">
        <rdf:RDF>
          <cc:Work rdf:about="">
            <dc:format>image/svg+xml</dc:format>
            <dc:type rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
            <dc:title>ActivityPub logo</dc:title>
            <cc:license rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/" />
            <dc:date>2017-04-15</dc:date>
            <dc:creator>
              <cc:Agent>
                <dc:title>Robert Martinez</dc:title>
              </cc:Agent>
            </dc:creator>
            <dc:subject>
              <rdf:Bag>
                <rdf:li>ActivityPub</rdf:li>
              </rdf:Bag>
            </dc:subject>
          </cc:Work>
          <cc:License rdf:about="http://creativecommons.org/publicdomain/zero/1.0/">
            <cc:permits rdf:resource="http://creativecommons.org/ns#Reproduction" />
            <cc:permits rdf:resource="http://creativecommons.org/ns#Distribution" />
            <cc:permits rdf:resource="http://creativecommons.org/ns#DerivativeWorks" />
          </cc:License>
        </rdf:RDF>
      </metadata>
      <g
        inkscape:label="Layer 1"
        inkscape:groupmode="layer"
        id="layer1"
        style="opacity:1"
        transform="translate(7.1437516,141.67967)"
      >
        <path
          style="fill:#000000;stroke-width:0.26458335"
          d=""
          id="path5497"
          inkscape:connector-curvature="0"
        />
        <g id="g5197" transform="translate(-4.2352716,0.01824528)">
          <g
            id="g5132-90"
            style="fill:url(#linearGradient7297-7);fill-opacity:1"
            transform="matrix(0.9789804,0,0,0.9789804,-3157.9561,1202.4422)"
          >
            <g
              transform="matrix(0.2553682,0,0,0.2553682,2615.9213,-1125.3113)"
              id="g5080-78"
              style="fill:url(#linearGradient8312);fill-opacity:1"
            >
              <path
                inkscape:connector-curvature="0"
                id="path5404-0-0"
                d="m 2450.431,-937.13662 51.9615,30 v 12 l -51.9615,30 v -12 l 41.5693,-24 -41.5692,-24 z"
                style="fill:url(#linearGradient8308);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:0.26458332px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
                sodipodi:nodetypes="cccccccc"
              />
              <path
                sodipodi:nodetypes="cccc"
                style="fill:url(#linearGradient8310);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:0.26458332px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
                d="m 2450.431,-913.13662 20.7847,12 -20.7847,12 z"
                id="path5406-6-3"
                inkscape:connector-curvature="0"
              />
            </g>
          </g>
          <g
            id="g5127-1"
            style="fill:url(#linearGradient7303-7);fill-opacity:1"
            transform="matrix(0.9789804,0,0,0.9789804,-3157.9561,1202.4422)"
          >
            <path
              id="path5467-2-0"
              transform="matrix(0.27026418,0,0,0.27026418,3225.7603,-1228.2597)"
              d="M 49.097656,-504.56641 0,-476.2207 v 11.33789 l 39.277344,-22.67578 v 45.35351 l 9.820312,5.66992 z m -19.638672,34.01563 -19.6406246,11.33789 19.6406246,11.33789 z"
              style="fill:url(#linearGradient8314);fill-opacity:1;fill-rule:evenodd;stroke:none;stroke-width:0.25000042px;stroke-linecap:butt;stroke-linejoin:miter;stroke-opacity:1"
              inkscape:connector-curvature="0"
            />
          </g>
        </g>
      </g>
      <style xmlns="" data-source="base" class="dblt-ykjmwcnxmi" /><style
        xmlns=""
        data-source="stylesheet-processor"
        class="dblt-ykjmwcnxmi"
      />
      <div xmlns="" id="saka-gui-root">
        <div>
          <div><style /></div>
        </div>
      </div>
    </svg>
    """
  end
end
