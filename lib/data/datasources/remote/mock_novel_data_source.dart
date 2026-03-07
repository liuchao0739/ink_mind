import '../../models/book.dart';
import '../../models/chapter.dart';
import 'novel_book_data_source.dart';

/// 模拟小说数据源，返回预设的小说数据
class MockNovelDataSource implements NovelBookDataSource {
  @override
  Future<List<Book>> searchRemote(String keyword) async {
    print('MockNovel: Searching for $keyword');
    
    // 预设的小说数据
    final novels = [
      Book(
        id: 'mock_jianlai',
        title: '剑来',
        author: '烽火戏诸侯',
        category: '玄幻',
        intro: '大千世界，无奇不有。我陈平安，唯有一剑，可搬山，断江，倒海，降妖，镇魔，敕神，摘星，摧城，开天！',
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: '/jianlai/',
        heatScore: 9999,
        status: '连载中',
      ),
      Book(
        id: 'mock_doupocangqiong',
        title: '斗破苍穹',
        author: '天蚕土豆',
        category: '玄幻',
        intro: '这里是天才云集的斗气大陆，强者为尊。少年萧炎，因为家族斗气消失，遭受种种打击，但他没有放弃，最终成为斗气大陆的巅峰强者！',
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: '/doupocangqiong/',
        heatScore: 8888,
        status: '完结',
      ),
      Book(
        id: 'mock_zhuixu',
        title: '赘婿',
        author: '愤怒的香蕉',
        category: '历史',
        intro: '现代金融界巨头穿越到古代，成为苏家赘婿，开启了一段波澜壮阔的人生。',
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: '/zhuixu/',
        heatScore: 7777,
        status: '完结',
      ),
      Book(
        id: 'mock_lingtian',
        title: '凌天传说',
        author: '风凌天下',
        category: '玄幻',
        intro: '凌天，一代天骄，穿越到异界，凭借着前世的记忆和智慧，在这个世界掀起了一场腥风血雨。',
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: '/lingtian/',
        heatScore: 6666,
        status: '完结',
      ),
      Book(
        id: 'mock_wudongqiankun',
        title: '武动乾坤',
        author: '天蚕土豆',
        category: '玄幻',
        intro: '林动，一个平凡的少年，偶然得到了一块神秘的石符，从此踏上了修炼之路，最终成为大千世界的强者。',
        sourceType: BookSourceType.publicDomainApi,
        remoteApiId: '/wudongqiankun/',
        heatScore: 5555,
        status: '完结',
      ),
    ];
    
    // 过滤匹配的小说
    final lowerKeyword = keyword.toLowerCase();
    final matchingNovels = novels.where((novel) {
      return novel.title.toLowerCase().contains(lowerKeyword) ||
             novel.author.toLowerCase().contains(lowerKeyword) ||
             novel.category.toLowerCase().contains(lowerKeyword);
    }).toList();
    
    print('MockNovel: Found ${matchingNovels.length} books');
    return matchingNovels;
  }

  @override
  Future<(Book, List<Chapter>)> fetchPublicDomainBook(String apiBookId) async {
    // 模拟获取小说详情和章节
    final book = Book(
      id: 'mock_${apiBookId.replaceAll('/', '')}',
      title: '模拟小说',
      author: '模拟作者',
      category: '玄幻',
      intro: '这是一本模拟小说，用于测试章节获取功能。',
      sourceType: BookSourceType.publicDomainApi,
      remoteApiId: apiBookId,
    );
    
    final chapters = [
      Chapter(
        id: '${apiBookId}_ch1',
        bookId: 'mock_${apiBookId.replaceAll('/', '')}',
        index: 0,
        title: '第一章 开始',
        content: '这是第一章的内容，测试章节获取功能。',
      ),
      Chapter(
        id: '${apiBookId}_ch2',
        bookId: 'mock_${apiBookId.replaceAll('/', '')}',
        index: 1,
        title: '第二章 发展',
        content: '这是第二章的内容，测试章节获取功能。',
      ),
      Chapter(
        id: '${apiBookId}_ch3',
        bookId: 'mock_${apiBookId.replaceAll('/', '')}',
        index: 2,
        title: '第三章 高潮',
        content: '这是第三章的内容，测试章节获取功能。',
      ),
    ];
    
    return (book, chapters);
  }

  @override
  Future<Book> fetchNovelDetail(String novelId) async {
    return Book(
      id: 'mock_${novelId.replaceAll('/', '')}',
      title: '模拟小说',
      author: '模拟作者',
      category: '玄幻',
      intro: '这是一本模拟小说，用于测试小说详情获取功能。',
      sourceType: BookSourceType.publicDomainApi,
      remoteApiId: novelId,
    );
  }

  @override
  Future<List<Chapter>> fetchChapterList(String novelId) async {
    return [
      Chapter(
        id: '${novelId}_ch1',
        bookId: 'mock_${novelId.replaceAll('/', '')}',
        index: 0,
        title: '第一章 开始',
        content: '',
      ),
      Chapter(
        id: '${novelId}_ch2',
        bookId: 'mock_${novelId.replaceAll('/', '')}',
        index: 1,
        title: '第二章 发展',
        content: '',
      ),
      Chapter(
        id: '${novelId}_ch3',
        bookId: 'mock_${novelId.replaceAll('/', '')}',
        index: 2,
        title: '第三章 高潮',
        content: '',
      ),
    ];
  }

  @override
  Future<String> fetchChapterContent(String chapterId, String novelId) async {
    return '这是章节 $chapterId 的内容，测试章节内容获取功能。';
  }

  @override
  Future<bool> isAvailable() async {
    return true;
  }
}
