"""
Class for generating YellowDog PDF reports. Subclass of FPDF.
"""

from os import path
from typing import Tuple

from fpdf import FPDF
from PIL import Image

# Constants
# Note: A4 paper is 210 x 297 mm
# Measurements below are in mm
A4_WIDTH: float = 210
A4_HEIGHT: float = 297

LEFT_MARGIN: float = 20
RIGHT_MARGIN: float = 20
CENTRE: float = A4_WIDTH / 2

TOP_GUTTER = 10
BOTTOM_GUTTER = 10
TOP_SPACER = 5
BOTTOM_SPACER = 5

WIDTH = A4_WIDTH - (LEFT_MARGIN + RIGHT_MARGIN)

FONT_FAMILY = "Helvetica"
FONT_FAMILY_FIXED = "Courier"
TEXT_COLOUR_DEFAULT: Tuple[int, int, int] = (69, 67, 96)
LINE_COLOUR_DEFAULT: Tuple[int, int, int] = (247, 171, 52)


class YellowPDF(FPDF):
    """
    A class to represent a YellowDog PDF document object.
    """

    def __init__(
        self,
        header_image: str = "yellowdog_header.png",
        footer_image: str = "yellowdog_footer.png",
        fonts_directory: str = "fonts/",
    ):
        """
        Constructor.

        Args:
            header_image (str, optional): The file containing the image
                to use for the document header. Set to 'None' if no header
                is required.
            footer_image (str, optional): The file containing the image
                to use for the document footer. Set to 'None' if no footer
                is required.
            fonts_directory (str, optional): Where to find the locally
                supplied fonts.
        """
        if header_image is not None:
            self._header_image: Image = Image.open(header_image)
            _, height_mm = self._image_dimensions_mm(self._header_image)
            self._top_margin_cached = height_mm + TOP_GUTTER + TOP_SPACER
        else:
            self._header_image = None
            self._top_margin_cached = TOP_GUTTER

        if footer_image is not None:
            self._footer_image: Image = Image.open(footer_image)
            _, height_mm = self._image_dimensions_mm(self._footer_image)
            self._bottom_margin_cached = height_mm + BOTTOM_GUTTER + BOTTOM_SPACER
        else:
            self._footer_image = None
            self._bottom_margin_cached = BOTTOM_GUTTER

        self._fonts_directory = fonts_directory
        super().__init__(orientation="P", unit="mm", format="A4")
        self.add_page()
        self.t_margin = self._top_margin_cached
        self.b_margin = self._bottom_margin_cached
        self.set_y(self.t_margin)  # FPDF doesn't respect top margin on first page
        # self._add_fonts()
        self.set_auto_page_break(True, margin=self.b_margin)

    def header(self):
        """
        This sets up the document header. This is done automatically.
        """
        if self._header_image is not None:
            self.image(self._header_image, x=LEFT_MARGIN, y=TOP_GUTTER, w=WIDTH)

    def footer(self):
        """
        This sets up the document footer. This is done automatically.
        """
        if self._footer_image is not None:
            self.image(
                self._footer_image,
                x=LEFT_MARGIN,
                y=A4_HEIGHT - self._bottom_margin_cached,
                w=WIDTH,
            )

    def print_horizontal_line(
        self,
        thickness: float = 0.2,
        before: float = 3.0,
        after: float = 3.0,
        indent: float = 0.0,
        colour: Tuple[int, int, int] = LINE_COLOUR_DEFAULT,
    ):
        """
        Draw a horizontal line.

        Args:
            thickness (float, optional): The thickness of the line in mm.
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            indent (float, optional): The left indent in mm.
            colour ((int, int, int)): The (R,G,B) colour to use.
        """
        self.set_draw_color(colour[0], colour[1], colour[2])
        self.set_line_width(thickness)
        self.set_y(self.y + before)
        self.line(int(LEFT_MARGIN + indent), self.y, A4_WIDTH - RIGHT_MARGIN, self.y)
        self.set_y(self.y + thickness + after)

    def print_title(
        self,
        text: str,
        before: float = 3.0,
        after: float = 3.0,
        font_size: float = 30.0,
        align: str = "L",
        indent: float = 0.0,
        colour: Tuple[int, int, int] = TEXT_COLOUR_DEFAULT,
    ):
        """
        Print a document title.

        Args:
            text (str): The document title.
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            font_size (float, optional): The font size to use.
            align (str, optional): Specify text alignment. Can be one of "L", "R",
                "J", or "C".
            indent (float, optional): The left indent in mm.
            colour ((int, int, int)): THE (R,G,B) colour for the font.
        """
        self.set_font(FONT_FAMILY, "B", font_size)
        self._set_text_colour(colour)
        self.set_y(self.y + before)
        self.set_x(LEFT_MARGIN + indent)
        self.multi_cell(
            int(WIDTH - indent), self._font_height(font_size), txt=text, align=align
        )
        self.set_y(self.y + after)

    def print_info_item(
        self,
        key: str,
        value: str,
        tab_stop: float = 90.0,
        before: float = 1.0,
        after: float = 1.0,
        font_size: float = 12.0,
        align: float = "L",
        colour: Tuple[int, int, int] = TEXT_COLOUR_DEFAULT,
    ):
        """
        Print an info item key:value pair.

        Args:
            key (str): The info field title
            value (str): The info field value
            tab_stop (float, optional) : The tab stop in mm for the print
                offset of the 'value' field.
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            font_size (float, optional): The font size to use.
            align (str, optional): Specify text alignment. Can be one of "L", "R",
                "J", or "C".
            colour ((int, int, int)): The (R,G,B) colour to use.
        """
        self.set_font(FONT_FAMILY, "", font_size)
        self.set_y(self.y + before)
        self.set_x(LEFT_MARGIN)
        y_position = self.y
        self._set_text_colour(colour)
        self.multi_cell(WIDTH, self._font_height(font_size), txt=key, markdown=True)

        self.set_font(FONT_FAMILY, "B", font_size)
        self.set_y(y_position)
        self.set_x(tab_stop)
        self._set_text_colour(colour)
        self.multi_cell(
            WIDTH - (tab_stop - LEFT_MARGIN),
            self._font_height(font_size),
            txt=value,
            align=align,
            markdown=False,
        )
        self.set_y(self.y + after)

    def print_heading(
        self,
        text: str,
        before: float = 6.0,
        after: float = 2.0,
        font_size: float = 13.0,
        align: str = "L",
        indent: float = 0.0,
        colour: Tuple[int, int, int] = TEXT_COLOUR_DEFAULT,
    ):
        """
        Print a section heading.

        Args:
            text (str): The heading text
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            font_size (float, optional): The font size to use.
            align (str, optional): Specify text alignment. Can be one of "L", "R",
                "J", or "C".
            indent (float, optional): The left indent in mm.
            colour ((int, int, int)): The (R,G,B) colour to use.
        """
        self.set_font(FONT_FAMILY, "B", font_size)
        self._set_text_colour(colour)
        self.set_y(self.y + before)
        self.set_x(LEFT_MARGIN + indent)
        self.multi_cell(
            int(WIDTH - indent), self._font_height(font_size), txt=text, align=align
        )
        self.set_y(self.y + after)

    def print_paragraph(
        self,
        text: str,
        before: float = 1.0,
        after: float = 1.0,
        bold: bool = False,
        italic: bool = False,
        font_size: float = 11.5,
        align: str = "J",
        indent: float = 0.0,
        colour: Tuple[int, int, int] = TEXT_COLOUR_DEFAULT,
        fixed_width: bool = False,
        markdown: bool = True,
    ):
        """
        Print a normal paragraph of text.

        Args:
            text (str): The paragraph text
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            bold (bool, optional): Use a bold font (can be used with `italic`).
            italic (bool, optional): Use an italic font (can be used with
                bold`).
            font_size (float, optional): The font size to use.
            align (str, optional): Specify text alignment. Can be one of "L", "R",
                "J", or "C".
            indent (float, optional): The left indent in mm.
            colour ((int, int, int)): The (R,G,B) colour to use.
            fixed_width: Whether to use the fixed width font.
            markdown: Whether to enable Markdown processing.
        """
        font_style = self._font_style(bold, italic)
        self.set_font(
            FONT_FAMILY if fixed_width is False else FONT_FAMILY_FIXED,
            font_style,
            font_size,
        )
        self._set_text_colour(colour)
        self.set_y(self.y + before)
        self.set_x(LEFT_MARGIN + indent)
        self.multi_cell(
            int(WIDTH - indent),
            self._font_height(font_size),
            txt=text,
            align=align,
            markdown=markdown,
        )
        self.set_y(self.y + after)

    def print_bulleted_text(
        self,
        text: str,
        bullet_indent: float = 0.0,
        indent: float = 8.0,
        before: float = 1.0,
        after: float = 1.0,
        bold: bool = False,
        italic: bool = False,
        font_size: float = 11.5,
        bullet: str = "-",
        align: str = "J",
        colour: Tuple[int, int, int] = TEXT_COLOUR_DEFAULT,
    ):
        """
        Print a bulleted paragraph of text.

        Args:
            text (str): The bulleted text.
            bullet_indent (float, optional) : The indentation of the bullet
                character itself, in mm.
            indent (float, optional): The indentation of the bulleted text, in mm.
                Note that this is offset by 'bullet_indent'.
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            bold (bool, optional): Use a bold font (can be used with `italic`).
            italic (bool, optional): Use an italic font (can be used with
                bold`).
            font_size (float, optional): The font size to use.
            bullet (str, optional): The character(s) to use for the bullet symbol.
            align (str, optional): Specify text alignment. Can be one of "L", "R",
                "J", or "C".
            colour ((int, int, int)): The (R,G,B) colour to use.
        """
        self._set_text_colour(colour)

        # Bullet
        font_style = self._font_style(bold, italic)
        self.set_font(FONT_FAMILY, font_style, font_size)
        self.set_y(self.y + before)

        # Avoid situation where bullet is printed at the end of one page,
        # text on the next page
        if self.y + self._font_height(font_size) > A4_HEIGHT - self.b_margin:
            self.insert_page_break()

        self.set_x(LEFT_MARGIN + bullet_indent)
        y_position = self.y
        width = self.get_string_width(bullet) + 3.0
        if width >= indent:
            indent = width + 1.0
        bottom_margin = self.b_margin
        self.set_auto_page_break(False)
        self.multi_cell(width, self._font_height(font_size), txt=bullet)
        self.set_auto_page_break(True, margin=bottom_margin)

        # Text
        self.set_font(FONT_FAMILY, font_style, font_size)
        self.set_xy(LEFT_MARGIN + bullet_indent + indent, y_position)
        self.multi_cell(
            WIDTH - (indent + bullet_indent),
            self._font_height(font_size),
            txt=text,
            align=align,
            markdown=True,
        )

        self.set_y(self.y + after)

    def print_image(
        self,
        image_file: str,
        expand: bool = False,
        before: float = 2.0,
        after: float = 2.0,
        indent: float = 0.0,
        align: str = "L",
    ):
        """
        Print an image.

        Args:
            image_file (str): The file containing the image.
            expand (bool, optional): Whether to expand images to fit the
                available page width.
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            indent (float, optional): The left indent in mm.
            align (str), optional): Image alignment for images that don't take up
                the available width: "L", "C" or "R". 'indent' will be respected.
        """

        image = Image.open(image_file)
        width_mm, _ = self._image_dimensions_mm(image)

        self.set_y(self.y + before)

        if width_mm <= (WIDTH - indent) and not expand:
            if align == "C":
                x_position = CENTRE - (width_mm / 2) + (indent / 2)
            elif align == "R":
                x_position = A4_WIDTH - RIGHT_MARGIN - width_mm
            else:  # "L" is the default
                x_position = LEFT_MARGIN + indent
            self.image(image, x=int(x_position), w=int(width_mm))
        else:
            x_position = LEFT_MARGIN + indent
            self.image(image, x=int(x_position), w=int(WIDTH - indent))

        self.set_y(self.y + after)

    def insert_page_break(self, orientation: str = "P"):
        """
        Insert a page break.
        """
        self.add_page(orientation=orientation)

    def insert_spacer(self, spacer: float = 5.0):
        """
        Insert vertical space.

        Args:
            spacer (float, optional): The amount of vertical space to
                introduce.
        """
        self.set_y(self.y + spacer)

    def print_hyperlink(
        self,
        url_text: str,
        url: str,
        indent: int = 0,
        before: float = 1.0,
        after: float = 1.0,
        font_size: float = 12.0,
        align: float = "L",
        colour: Tuple[int, int, int] = LINE_COLOUR_DEFAULT,
    ):
        """
        Print a hyperlink.

        Args:
            url_text (str): The text shown for the URL.
            url (str): The URL.
            indent (int, optional): Paragraph indentation in mm.
            before (float, optional): The vertical space to leave before printing
                the item, in mm.
            after (float, optional): The vertical space to leave after printing
                the item, in mm.
            font_size (float, optional): The font size to use.
            align (str, optional): Specify text alignment. Can be one of "L", "R",
                "J", or "C".
            colour ((int, int, int)): The (R,G,B) colour to use.
        """
        self.set_font(family=FONT_FAMILY, style="U", size=font_size)
        self.set_y(self.y + before)
        self.set_x(LEFT_MARGIN + indent)
        self._set_text_colour(colour)

        url_text_x = self.x
        url_text_y = self.y

        # Print the url_text
        self.multi_cell(
            WIDTH, self._font_height(font_size), txt=url_text, markdown=True
        )

        # Calculate the link bounding box, and set up the link
        width = self.get_string_width(url_text)
        height = 5
        self.link(x=url_text_x, y=url_text_y, w=width, h=height, link=f"{url}")

        self.set_y(self.y + after)

    def generate_pdf_file(self, filename: str):
        """
        Generate the PDF file.

        Args:
            filename (str): The name of the pdf file to generate.
        """
        self.output(filename)

    def _set_text_colour(self, colour: Tuple[int, int, int]):
        """
        Set the text colour.

        Args:
            (int, int, int): A three-tuple containing the R,G,B
                values.
        """
        self.set_text_color(colour[0], colour[1], colour[2])

    def _add_fonts(self):
        """
        Load the required local fonts.
        Not currently used for YellowDog.
        """
        self.add_font(
            "Montserrat",
            "",
            path.join(self._fonts_directory, "Montserrat/Montserrat-Medium.ttf"),
            uni=True,
        )
        self.add_font(
            "Montserrat",
            "B",
            path.join(self._fonts_directory, "Montserrat/Montserrat-Bold.ttf"),
            uni=True,
        )
        self.add_font(
            "Montserrat",
            "I",
            path.join(self._fonts_directory, "Montserrat/Montserrat-MediumItalic.ttf"),
            uni=True,
        )
        self.add_font(
            "Montserrat",
            "BI",
            path.join(self._fonts_directory, "Montserrat/Montserrat-BoldItalic.ttf"),
            uni=True,
        )

    @staticmethod
    def _font_style(bold: bool, italic: bool):
        """
        Determine the required font style.

        Args:
            bold (bool): Whether the font is bold.
            italic (bool): Whether the font is italic.

        Returns:
            str: The font style string.
        """
        font_style = ""
        if bold:
            font_style += "B"
        if italic:
            font_style += "I"
        return font_style

    @staticmethod
    def _font_height(font_size: float):
        """
        The vertical space to allow in a multi_cell.

        Args:
            font_size (float): Font size in points.

        Returns:
            int: The vertical height to specify when outputting
                a 'multi_cell', in mm.
        """
        return int(font_size / 2.0)

    @staticmethod
    def _image_dimensions_mm(image: Image):
        """Determine the width and height of a PIL image in mm.

        Args:
            image (Image): The PIL image object.

        Returns:
            (float, float): The width and height in mm.
        """
        try:
            dpi_x, dpi_y = image.info["dpi"]
        except KeyError:
            dpi_x = dpi_y = 300
        mm_in_inch = 25.4
        width_mm = image.width / (dpi_x / mm_in_inch)
        height_mm = image.height / (dpi_y / mm_in_inch)
        return width_mm, height_mm
