import 'dart:convert';
import 'package:bridge_lib/bridge_lib.dart';

getPopularAnime(MangaModel anime) async {
  final data = {"url": "${anime.baseUrl}/most-popular?page=${anime.page}"};
  final res = await MBridge.http('GET', json.encode(data));
  if (res.isEmpty) {
    return anime;
  }

  return animeElementM(res, anime);
}

getLatestUpdatesAnime(MangaModel anime) async {
  final data = {"url": "${anime.baseUrl}/top-airing?page=${anime.page}"};
  final res = await MBridge.http('GET', json.encode(data));
  if (res.isEmpty) {
    return anime;
  }
  return animeElementM(res, anime);
}

getAnimeDetail(MangaModel anime) async {
  final statusList = [
    {
      "Currently Airing": 0,
      "Finished Airing": 1,
    }
  ];
  final url = "${anime.baseUrl}${anime.link}";
  final data = {"url": url, "headers": null};
  final res = await MBridge.http('GET', json.encode(data));
  if (res.isEmpty) {
    return anime;
  }

  final status = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Status:")]/span[2]/text()')
      .first;
  anime.status = MBridge.parseStatus(status, statusList);
  anime.author = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Studios:")]/span/text()')
      .first
      .replaceAll("Studios:", "");
  final aired = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Aired:")]/span/text()')
      .first;
  final japanese = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Japanese:")]/span/text()')
      .first;
  final synonyms = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Synonyms:")]/span/text()')
      .first;
  final premiered = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Premiered:")]/span/text()')
      .first;
  final overview = MBridge.xpath(res,
          '//*[@class="anisc-info"]/div[contains(text(),"Overview:")]/text()')
      .first
      .replaceAll("Overview:", "");
  String description = "$overview\n\n$japanese\n$synonyms\n$aired\n$premiered";
  anime.description = description;
  final genre = MBridge.xpath(
      res, '//*[@class="anisc-info"]/div[contains(text(),"Genres:")]/a/text()');

  anime.genre = genre;

  final id = MBridge.substringAfterLast(anime.link, '-');
  final urlEp =
      "${anime.baseUrl}/ajax${ajaxRoute('${anime.baseUrl}')}/episode/list/$id";

  final dataEp = {
    "url": urlEp,
    "headers": {"referer": url}
  };
  final resEp = await MBridge.http('GET', json.encode(dataEp));

  final html = json.decode(resEp)["html"];

  final epUrls = MBridge.querySelectorAll(html,
      selector: "a.ep-item", typeElement: 3, attributes: "href", typeRegExp: 0);

  anime.urls = epUrls.reversed.toList();

  final numbers = MBridge.querySelectorAll(html,
      selector: "a.ep-item",
      typeElement: 3,
      attributes: "data-number",
      typeRegExp: 0);

  final titles = MBridge.querySelectorAll(html,
      selector: "a.ep-item",
      typeElement: 3,
      attributes: "title",
      typeRegExp: 0);

  List<String> episodes = [];

  for (var i = 0; i < titles.length; i++) {
    final number = numbers[i];
    final title = titles[i];
    episodes.add("Episode $number: $title");
  }

  anime.names = episodes.reversed.toList();
  anime.chaptersDateUploads = [];
  return anime;
}

searchAnime(MangaModel anime) async {
  final data = {
    "url": "${anime.baseUrl}/search?keyword=${anime.query}&page=${anime.page}"
  };
  final res = await MBridge.http('GET', json.encode(data));
  if (res.isEmpty) {
    return anime;
  }
  return animeElementM(res, anime);
}

getVideoList(MangaModel anime) async {
  final id = MBridge.substringAfterLast(anime.link, '?ep=');
  final datas = {
    "url":
        "${anime.baseUrl}/ajax${ajaxRoute('${anime.baseUrl}')}/episode/servers?episodeId=$id",
    "headers": {"referer": "${anime.baseUrl}/${anime.link}"},
    "sourceId": anime.sourceId
  };

  final res = await MBridge.http('GET', json.encode(datas));

  if (res.isEmpty) {
    return [];
  }
  final html = json.decode(res)["html"];

  final names = MBridge.querySelectorAll(html,
      selector: "div.server-item",
      typeElement: 0,
      attributes: "",
      typeRegExp: 0);

  final ids = MBridge.querySelectorAll(html,
      selector: "div.server-item",
      typeElement: 3,
      attributes: "data-id",
      typeRegExp: 0);

  final subDubs = MBridge.querySelectorAll(html,
      selector: "div.server-item",
      typeElement: 3,
      attributes: "data-type",
      typeRegExp: 0);

  List<VideoModel> videos = [];

  for (var i = 0; i < names.length; i++) {
    final name = names[i];
    final id = ids[i];
    final subDub = subDubs[i];
    final datasE = {
      "url":
          "${anime.baseUrl}/ajax${ajaxRoute('${anime.baseUrl}')}/episode/sources?id=$id",
      "headers": {"referer": "${anime.baseUrl}/${anime.link}"}
    };

    final resE = await MBridge.http('GET', json.encode(datasE));
    String url = MBridge.substringBefore(
        MBridge.substringAfter(resE, "\"link\":\""), "\"");
    print(url);
    List<VideoModel> a = [];
    if (name.contains("Vidstreaming")) {
      a = await MBridge.rapidCloudExtractor(url, "Vidstreaming - $subDub");
    } else if (name.contains("Vidcloud")) {
      a = await MBridge.rapidCloudExtractor(url, "Vidcloud - $subDub");
    } else if (name.contains("StreamTape")) {
      a = await MBridge.streamTapeExtractor(url, "StreamTape - $subDub");
    }
    for (var vi in a) {
      videos.add(vi);
    }
  }

  return videos;
}

MangaModel animeElementM(String res, MangaModel anime) async {
  if (res.isEmpty) {
    return anime;
  }
  anime.urls = MBridge.xpath(
      res, '//*[@class^="flw-item"]/div[@class="film-detail"]/h3/a/@href');

  anime.names = MBridge.xpath(res,
      '//*[@class^="flw-item"]/div[@class="film-detail"]/h3/a/@data-jname');

  anime.images = MBridge.xpath(
      res, '//*[@class^="flw-item"]/div[@class="film-poster"]/img/@data-src');
  final nextPage =
      MBridge.xpath(res, '//li[@class="page-item"]/a[@title="Next"]/@href', "");
  if (nextPage.isEmpty) {
    anime.hasNextPage = false;
  } else {
    anime.hasNextPage = true;
  }
  return anime;
}

String ajaxRoute(String baseUrl) {
  if (baseUrl == "https://kaido.to") {
    return "";
  }
  return "/v2";
}
